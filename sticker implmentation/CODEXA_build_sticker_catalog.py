#!/usr/bin/env python3
"""Build an offline Flutter sticker asset catalog from loose images and ZIP archives.

No cloud/database access. Run from the Flutter repository root.
"""
import argparse
import hashlib
import json
import shutil
from collections import defaultdict
from pathlib import Path, PurePosixPath
from zipfile import ZipFile, BadZipFile

EXT = {'.webp', '.png', '.gif'}
LIMIT_PER_ASSET = 20 * 1024 * 1024  # safety limit, tune with actual renderer tests
LIMIT_ZIP_UNPACKED = 600 * 1024 * 1024


def detect_image(data):
    if len(data) >= 12 and data[:4] == b'RIFF' and data[8:12] == b'WEBP':
        # ANIM and ANMF are WebP animation chunk tags; sufficient for classification.
        return '.webp', 'image/webp', (b'ANIM' in data or b'ANMF' in data)
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        return '.png', 'image/png', False
    if data.startswith((b'GIF87a', b'GIF89a')):
        return '.gif', 'image/gif', True
    return None


def valid_zip_item(info):
    name = info.filename.replace('\\', '/')
    p = PurePosixPath(name)
    if info.is_dir() or name.startswith('/') or '..' in p.parts or ':' in p.parts[0]:
        return False
    # Unix symlinks in ZIP external attrs
    mode = info.external_attr >> 16
    if (mode & 0o170000) == 0o120000:
        return False
    return p.suffix.lower() in EXT


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', default='assets/stickers/source')
    ap.add_argument('--out', default='assets/stickers/bundled')
    ap.add_argument('--manifest', default='assets/stickers/catalog.json')
    ap.add_argument('--report', default='assets/stickers/import-report.json')
    args = ap.parse_args()
    src, out, manifest, report = (Path(x) for x in (args.source, args.out, args.manifest, args.report))
    if not src.is_dir():
        raise SystemExit(f'Missing sticker source directory: {src}')
    out.mkdir(parents=True, exist_ok=True)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)

    stickers = {}
    packs = defaultdict(set)
    rejected = []
    counts = defaultdict(int)
    needed_paths = set()

    def ingest(data, origin, pack):
        if not data or len(data) > LIMIT_PER_ASSET:
            counts['invalid_or_oversized'] += 1
            rejected.append({'source': origin, 'reason': 'empty_or_oversized'})
            return
        fmt = detect_image(data)
        if not fmt:
            counts['bad_signature'] += 1
            rejected.append({'source': origin, 'reason': 'unsupported_signature'})
            return
        suffix, mime, animated = fmt
        digest = hashlib.sha256(data).hexdigest()
        path = out / f'{digest}{suffix}'
        if digest not in stickers:
            if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                path.write_bytes(data)
            stickers[digest] = {
                'id': digest,
                'assetPath': path.as_posix(),
                'mimeType': mime,
                'animated': animated,
                'sha256': digest,
                'byteLength': len(data),
            }
            needed_paths.add(path)
            counts['unique_accepted'] += 1
        else:
            counts['duplicate_content'] += 1
        packs[pack].add(digest)
        counts['accepted_references'] += 1

    for file in sorted(src.rglob('*')):
        if not file.is_file():
            continue
        suffix = file.suffix.lower()
        relative = file.relative_to(src).as_posix()
        pack = f'folder:{file.parent.relative_to(src).as_posix()}'
        try:
            if suffix in EXT:
                counts['source_image_files'] += 1
                if file.stat().st_size > LIMIT_PER_ASSET:
                    ingest(b'', relative, pack)
                else:
                    ingest(file.read_bytes(), relative, pack)
            elif suffix == '.zip':
                counts['source_zip_files'] += 1
                try:
                    with ZipFile(file) as z:
                        declared_total = sum(i.file_size for i in z.infolist())
                        if declared_total > LIMIT_ZIP_UNPACKED:
                            raise ValueError('zip_declared_unpacked_too_large')
                        for info in z.infolist():
                            if not valid_zip_item(info):
                                continue
                            if info.file_size > LIMIT_PER_ASSET:
                                rejected.append({'source': f'{relative}!{info.filename}', 'reason': 'oversized_zip_member'})
                                counts['invalid_or_oversized'] += 1
                                continue
                            with z.open(info) as fp:
                                data = fp.read(LIMIT_PER_ASSET + 1)
                            ingest(data, f'{relative}!{info.filename}', f'archive:{relative}')
                            counts['zip_image_members'] += 1
                except (BadZipFile, OSError, RuntimeError, ValueError) as e:
                    rejected.append({'source': relative, 'reason': type(e).__name__ + ':' + str(e)[:120]})
                    counts['bad_archives'] += 1
            elif suffix in ('.was', '.enc'):
                counts['unsupported_special_files'] += 1
                rejected.append({'source': relative, 'reason': 'unsupported_format_' + suffix})
            elif suffix == '.nomedia':
                counts['ignored_nomedia'] += 1
            else:
                counts['other_skipped'] += 1
                rejected.append({'source': relative, 'reason': 'not_a_supported_sticker_file'})
        except (OSError, ValueError) as e:
            rejected.append({'source': relative, 'reason': type(e).__name__ + ':' + str(e)[:120]})
            counts['processing_errors'] += 1

    # Pack IDs are derived from labels (not sequential positions); sticker IDs from bytes.
    pack_list = []
    for label, ids in sorted(packs.items()):
        pack_id = hashlib.sha256(label.encode()).hexdigest()[:24]
        pack_list.append({'id': pack_id, 'name': label, 'stickerIds': sorted(ids)})
    ids = sorted(stickers)
    catalog_version = hashlib.sha256(('|'.join(ids) + '\n' + json.dumps(pack_list, sort_keys=True)).encode()).hexdigest()[:20]
    payload = {'schemaVersion': 1, 'catalogVersion': catalog_version,
               'stickers': [stickers[i] for i in ids], 'packs': pack_list}
    manifest.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    result = {'source': str(src), 'catalogVersion': catalog_version,
              'counts': dict(counts), 'manifestStickerCount': len(stickers),
              'totalUniqueAssetBytes': sum(i['byteLength'] for i in stickers.values()),
              'rejected': rejected}
    report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: result[k] for k in ('catalogVersion', 'counts', 'manifestStickerCount', 'totalUniqueAssetBytes')}, indent=2))
    print(f'Manifest: {manifest} | Report: {report}')
    # Do not remove stale assets automatically; an older persisted sticker reference could require them.


if __name__ == '__main__':
    main()
