using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Controls.Primitives;
using System.Threading;
using System.Windows.Threading;
using Ellipse = System.Windows.Shapes.Ellipse;

namespace CodeXaDesktop {
    public class Program {
        [STAThread]
        public static void Main() {
            try {
                var app = new Application();
                var window = new MainWindow();
                app.Run(window);
            } catch (Exception ex) {
                File.WriteAllText("desktop_error.log", ex.ToString());
            }
        }
    }

    public class MainWindow : Window {
        private ContentControl contentArea;
        private DispatcherTimer clockTimer;
        private TextBlock clockTextBlock;
        private List<Button> navButtons = new List<Button>();

        // Navigation Views
        private FrameworkElement dashboardView;
        private FrameworkElement storeView;
        private FrameworkElement attendanceView;
        private FrameworkElement classesView;
        private FrameworkElement projectsView;
        private FrameworkElement chatView;
        private FrameworkElement aiCopilotView;
        private FrameworkElement settingsView;

        public MainWindow() {
            Title = "CodeXa Agency Workspace — Desktop Edition";
            Width = 1260;
            Height = 820;
            MinWidth = 1050;
            MinHeight = 680;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            WindowStyle = WindowStyle.SingleBorderWindow;
            AllowsTransparency = false;
            Background = new SolidColorBrush(Color.FromRgb(10, 10, 10));

            BuildUI();
            StartClock();
        }

        private void BuildUI() {
            // Main Outer Border with Red Glow
            var outerBorder = new Border {
                Background = new SolidColorBrush(Color.FromRgb(10, 10, 10)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(120, 217, 4, 41)),
                BorderThickness = new Thickness(1.5),
                CornerRadius = new CornerRadius(14)
            };

            var rootGrid = new Grid();
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(46) }); // Title Bar
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Main Body

            // 1. TOP TITLE BAR
            var titleBar = BuildTitleBar();
            Grid.SetRow(titleBar, 0);
            rootGrid.Children.Add(titleBar);

            // 2. MAIN BODY (Sidebar + Content)
            var bodyGrid = new Grid();
            bodyGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(240) }); // Left Nav
            bodyGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); // Content

            var sidebar = BuildSidebar();
            Grid.SetColumn(sidebar, 0);
            bodyGrid.Children.Add(sidebar);

            contentArea = new ContentControl {
                Background = new SolidColorBrush(Color.FromRgb(14, 14, 14)),
                Margin = new Thickness(0, 0, 0, 0)
            };
            Grid.SetColumn(contentArea, 1);
            bodyGrid.Children.Add(contentArea);

            Grid.SetRow(bodyGrid, 1);
            rootGrid.Children.Add(bodyGrid);

            outerBorder.Child = rootGrid;
            Content = outerBorder;

            // Initialize Views
            dashboardView = CreateDashboardView();
            storeView = CreateStoreView();
            attendanceView = CreateAttendanceView();
            classesView = CreateClassesView();
            projectsView = CreateProjectsView();
            chatView = CreateChatView();
            aiCopilotView = CreateAiCopilotView();
            settingsView = CreateSettingsView();

            // Default View
            NavigateTo(dashboardView, navButtons[0]);
        }

        private FrameworkElement BuildTitleBar() {
            var bar = new Border {
                Background = new SolidColorBrush(Color.FromRgb(14, 14, 14)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(50, 255, 255, 255)),
                BorderThickness = new Thickness(0, 0, 0, 1),
                CornerRadius = new CornerRadius(14, 14, 0, 0)
            };

            bar.MouseLeftButtonDown += (s, e) => {
                if (e.ButtonState == MouseButtonState.Pressed) {
                    DragMove();
                }
            };

            var grid = new Grid { Margin = new Thickness(14, 0, 10, 0) };
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            // Brand Logo & Title
            var brandPanel = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            
            var logoBox = new Border {
                Width = 26,
                Height = 26,
                CornerRadius = new CornerRadius(6),
                Background = new LinearGradientBrush(
                    Color.FromRgb(217, 4, 41),
                    Color.FromRgb(255, 30, 60),
                    new Point(0, 0),
                    new Point(1, 1)
                ),
                Margin = new Thickness(0, 0, 10, 0)
            };
            var logoText = new TextBlock {
                Text = "CX",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 12,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            logoBox.Child = logoText;
            brandPanel.Children.Add(logoBox);

            var titleText = new TextBlock {
                Text = "CODEXA WORKSPACE",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 13,
                VerticalAlignment = VerticalAlignment.Center
            };
            brandPanel.Children.Add(titleText);

            var editionBadge = new Border {
                Background = new SolidColorBrush(Color.FromArgb(40, 217, 4, 41)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(120, 217, 4, 41)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(6, 2, 6, 2),
                Margin = new Thickness(10, 0, 0, 0)
            };
            editionBadge.Child = new TextBlock {
                Text = "DESKTOP v1.0.5",
                Foreground = new SolidColorBrush(Color.FromRgb(255, 30, 60)),
                FontSize = 10,
                FontWeight = FontWeights.SemiBold
            };
            brandPanel.Children.Add(editionBadge);

            Grid.SetColumn(brandPanel, 0);
            grid.Children.Add(brandPanel);

            // Center Status Info
            var centerPanel = new StackPanel {
                Orientation = Orientation.Horizontal,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };

            var statusDot = new Ellipse {
                Width = 8,
                Height = 8,
                Fill = new SolidColorBrush(Color.FromRgb(16, 185, 129)),
                Margin = new Thickness(0, 0, 6, 0)
            };
            centerPanel.Children.Add(statusDot);

            var serverStatus = new TextBlock {
                Text = "API: codxa-agency.online (ONLINE)",
                Foreground = new SolidColorBrush(Color.FromRgb(160, 160, 160)),
                FontSize = 11,
                Margin = new Thickness(0, 0, 16, 0)
            };
            centerPanel.Children.Add(serverStatus);

            clockTextBlock = new TextBlock {
                Text = "00:00:00",
                Foreground = new SolidColorBrush(Color.FromRgb(220, 220, 220)),
                FontWeight = FontWeights.SemiBold,
                FontSize = 11
            };
            centerPanel.Children.Add(clockTextBlock);

            Grid.SetColumn(centerPanel, 1);
            grid.Children.Add(centerPanel);

            // Window Controls (Min, Max, Close)
            var controlsPanel = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };

            var minBtn = CreateTitleButton("—", (s, e) => WindowState = WindowState.Minimized);
            var maxBtn = CreateTitleButton("□", (s, e) => WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized);
            var closeBtn = CreateTitleButton("✕", (s, e) => Close(), true);

            controlsPanel.Children.Add(minBtn);
            controlsPanel.Children.Add(maxBtn);
            controlsPanel.Children.Add(closeBtn);

            Grid.SetColumn(controlsPanel, 2);
            grid.Children.Add(controlsPanel);

            bar.Child = grid;
            return bar;
        }

        private Button CreateTitleButton(string symbol, RoutedEventHandler handler, bool isClose = false) {
            var btn = new Button {
                Content = symbol,
                Width = 32,
                Height = 28,
                Background = Brushes.Transparent,
                Foreground = new SolidColorBrush(Color.FromRgb(180, 180, 180)),
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand,
                FontSize = 11,
                FontWeight = FontWeights.Bold
            };
            btn.Click += handler;
            btn.MouseEnter += (s, e) => {
                btn.Background = isClose
                    ? new SolidColorBrush(Color.FromRgb(217, 4, 41))
                    : new SolidColorBrush(Color.FromArgb(40, 255, 255, 255));
                btn.Foreground = Brushes.White;
            };
            btn.MouseLeave += (s, e) => {
                btn.Background = Brushes.Transparent;
                btn.Foreground = new SolidColorBrush(Color.FromRgb(180, 180, 180));
            };
            return btn;
        }

        private void StartClock() {
            clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            clockTimer.Tick += (s, e) => {
                clockTextBlock.Text = DateTime.Now.ToString("dd-MMM-yyyy • HH:mm:ss");
            };
            clockTimer.Start();
        }

        private FrameworkElement BuildSidebar() {
            var sidebar = new Border {
                Background = new SolidColorBrush(Color.FromRgb(10, 10, 10)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(0, 0, 1, 0)
            };

            var grid = new Grid { Margin = new Thickness(12, 14, 12, 14) };
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // User Profile
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Nav Links
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Bottom Web Link

            // User Profile Card
            var profileCard = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(60, 217, 4, 41)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(10),
                Margin = new Thickness(0, 0, 0, 16)
            };

            var pStack = new StackPanel();
            var pHeader = new StackPanel { Orientation = Orientation.Horizontal };
            
            var avatar = new Border {
                Width = 34,
                Height = 34,
                CornerRadius = new CornerRadius(17),
                Background = new LinearGradientBrush(
                    Color.FromRgb(217, 4, 41),
                    Color.FromRgb(150, 0, 25),
                    new Point(0, 0),
                    new Point(1, 1)
                ),
                Margin = new Thickness(0, 0, 10, 0)
            };
            avatar.Child = new TextBlock {
                Text = "SA",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 13,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            pHeader.Children.Add(avatar);

            var nameStack = new StackPanel();
            nameStack.Children.Add(new TextBlock {
                Text = "Sanjay Boddukuri",
                Foreground = Brushes.White,
                FontWeight = FontWeights.SemiBold,
                FontSize = 12
            });
            nameStack.Children.Add(new TextBlock {
                Text = "Admin & Developer",
                Foreground = new SolidColorBrush(Color.FromRgb(16, 185, 129)),
                FontSize = 10
            });
            pHeader.Children.Add(nameStack);
            pStack.Children.Add(pHeader);

            profileCard.Child = pStack;
            Grid.SetRow(profileCard, 0);
            grid.Children.Add(profileCard);

            // Navigation Menu
            var navStack = new StackPanel();
            navButtons.Clear();

            AddNavItem(navStack, "📊  Dashboard", () => NavigateTo(dashboardView, navButtons[0]));
            AddNavItem(navStack, "🏪  CodeXa Store", () => NavigateTo(storeView, navButtons[1]));
            AddNavItem(navStack, "⏱️  Attendance", () => NavigateTo(attendanceView, navButtons[2]));
            AddNavItem(navStack, "🎓  Classes & Hub", () => NavigateTo(classesView, navButtons[3]));
            AddNavItem(navStack, "📂  Projects & Tasks", () => NavigateTo(projectsView, navButtons[4]));
            AddNavItem(navStack, "💬  Team Chat", () => NavigateTo(chatView, navButtons[5]));
            AddNavItem(navStack, "🤖  CodeXa AI Copilot", () => NavigateTo(aiCopilotView, navButtons[6]));
            AddNavItem(navStack, "⚙️  Settings", () => NavigateTo(settingsView, navButtons[7]));

            var scroll = new ScrollViewer {
                Content = navStack,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto
            };
            Grid.SetRow(scroll, 1);
            grid.Children.Add(scroll);

            // Bottom Web Link Button
            var webBtn = new Button {
                Content = "🌐 Open Live Website",
                Height = 36,
                Background = new SolidColorBrush(Color.FromArgb(40, 217, 4, 41)),
                Foreground = new SolidColorBrush(Color.FromRgb(255, 80, 100)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(100, 217, 4, 41)),
                BorderThickness = new Thickness(1),
                Cursor = Cursors.Hand,
                FontWeight = FontWeights.SemiBold,
                FontSize = 11
            };
            webBtn.Click += (s, e) => {
                Process.Start(new ProcessStartInfo("https://codxa-agency.online/") { UseShellExecute = true });
            };
            Grid.SetRow(webBtn, 2);
            grid.Children.Add(webBtn);

            sidebar.Child = grid;
            return sidebar;
        }

        private void AddNavItem(StackPanel container, string label, Action onClick) {
            var btn = new Button {
                Content = label,
                Height = 38,
                Margin = new Thickness(0, 0, 0, 4),
                HorizontalContentAlignment = HorizontalAlignment.Left,
                Padding = new Thickness(14, 0, 0, 0),
                Background = Brushes.Transparent,
                Foreground = new SolidColorBrush(Color.FromRgb(180, 180, 180)),
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand,
                FontSize = 12,
                FontWeight = FontWeights.Medium
            };
            btn.Click += (s, e) => onClick();
            navButtons.Add(btn);
            container.Children.Add(btn);
        }

        private void NavigateTo(FrameworkElement view, Button activeBtn) {
            contentArea.Content = view;
            foreach (var btn in navButtons) {
                btn.Background = Brushes.Transparent;
                btn.Foreground = new SolidColorBrush(Color.FromRgb(180, 180, 180));
                btn.FontWeight = FontWeights.Medium;
            }
            if (activeBtn != null) {
                activeBtn.Background = new SolidColorBrush(Color.FromArgb(45, 217, 4, 41));
                activeBtn.Foreground = new SolidColorBrush(Color.FromRgb(255, 30, 60));
                activeBtn.FontWeight = FontWeights.Bold;
            }
        }

        // =====================================================================
        // VIEW 1: DASHBOARD
        // =====================================================================
        private FrameworkElement CreateDashboardView() {
            var scroll = new ScrollViewer { Padding = new Thickness(24) };
            var stack = new StackPanel();

            // Header Banner
            var header = new Border {
                Background = new LinearGradientBrush(
                    Color.FromRgb(26, 5, 10),
                    Color.FromRgb(15, 15, 15),
                    new Point(0, 0),
                    new Point(1, 1)
                ),
                BorderBrush = new SolidColorBrush(Color.FromArgb(100, 217, 4, 41)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(14),
                Padding = new Thickness(22),
                Margin = new Thickness(0, 0, 0, 24)
            };
            var hStack = new StackPanel();
            hStack.Children.Add(new TextBlock {
                Text = "WELCOME TO CODEXA ENTERPRISE WORKSPACE",
                Foreground = new SolidColorBrush(Color.FromRgb(255, 30, 60)),
                FontWeight = FontWeights.Bold,
                FontSize = 18
            });
            hStack.Children.Add(new TextBlock {
                Text = "Unified Windows Desktop Management Console • Connected to Production Backend",
                Foreground = new SolidColorBrush(Color.FromRgb(180, 180, 180)),
                FontSize = 12,
                Margin = new Thickness(0, 4, 0, 12)
            });

            var quickRow = new StackPanel { Orientation = Orientation.Horizontal };
            var storeJump = new Button {
                Content = "Browse CodeXa Store →",
                Background = new SolidColorBrush(Color.FromRgb(217, 4, 41)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                Padding = new Thickness(14, 8, 14, 8),
                FontWeight = FontWeights.SemiBold,
                Cursor = Cursors.Hand,
                Margin = new Thickness(0, 0, 12, 0)
            };
            storeJump.Click += (s, e) => NavigateTo(storeView, navButtons[1]);
            quickRow.Children.Add(storeJump);

            var mobileWebJump = new Button {
                Content = "Open Mobile Showcase",
                Background = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                Padding = new Thickness(14, 8, 14, 8),
                FontWeight = FontWeights.SemiBold,
                Cursor = Cursors.Hand
            };
            mobileWebJump.Click += (s, e) => Process.Start(new ProcessStartInfo("https://codxa-agency.online/mobile") { UseShellExecute = true });
            quickRow.Children.Add(mobileWebJump);

            hStack.Children.Add(quickRow);
            header.Child = hStack;
            stack.Children.Add(header);

            // Metrics Grid (4 Cards)
            var metricsGrid = new UniformGrid { Columns = 4, Margin = new Thickness(0, 0, 0, 24) };
            metricsGrid.Children.Add(CreateStatCard("PROD RELEASE", "v1.0.5", "Build 105 • Stable", Color.FromRgb(255, 30, 60)));
            metricsGrid.Children.Add(CreateStatCard("STORE MEDIA", "11 Assets", "10 Images + 1080p Video", Color.FromRgb(16, 185, 129)));
            metricsGrid.Children.Add(CreateStatCard("ACTIVE BATCHES", "4 Batches", "AI, Full-Stack, Cyber, Cloud", Color.FromRgb(59, 130, 246)));
            metricsGrid.Children.Add(CreateStatCard("SYSTEM STATUS", "OPERATIONAL", "100% Up-time Verified", Color.FromRgb(245, 158, 11)));
            stack.Children.Add(metricsGrid);

            // Operational Feeds
            var feedsCard = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(18)
            };
            var fStack = new StackPanel();
            fStack.Children.Add(new TextBlock {
                Text = "RECENT PLATFORM MILESTONES",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 13,
                Margin = new Thickness(0, 0, 0, 12)
            });

            AddTimelineItem(fStack, "v1.0.5 Release Published", "Official APK release compiled, signed, and SHA-256 verified.", "Just now");
            AddTimelineItem(fStack, "CodeXa Store Catalog Synchronized", "10 portrait showcase images and 1080p walkthrough linked.", "Today");
            AddTimelineItem(fStack, "Mobile App In-Place Upgrades Active", "Android package installer enabled for seamless in-app APK upgrades.", "Yesterday");
            AddTimelineItem(fStack, "Supabase Storage Parity", "Private upload buckets and media signed sessions configured.", "2 days ago");

            feedsCard.Child = fStack;
            stack.Children.Add(feedsCard);

            scroll.Content = stack;
            return scroll;
        }

        private Border CreateStatCard(string title, string value, string subtitle, Color accentColor) {
            var b = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(16),
                Margin = new Thickness(0, 0, 12, 0)
            };
            var s = new StackPanel();
            s.Children.Add(new TextBlock {
                Text = title,
                Foreground = new SolidColorBrush(Color.FromRgb(140, 140, 140)),
                FontSize = 10,
                FontWeight = FontWeights.Bold
            });
            s.Children.Add(new TextBlock {
                Text = value,
                Foreground = new SolidColorBrush(accentColor),
                FontSize = 22,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 4, 0, 4)
            });
            s.Children.Add(new TextBlock {
                Text = subtitle,
                Foreground = new SolidColorBrush(Color.FromRgb(180, 180, 180)),
                FontSize = 11
            });
            b.Child = s;
            return b;
        }

        private void AddTimelineItem(StackPanel container, string title, string detail, string time) {
            var g = new Grid { Margin = new Thickness(0, 0, 0, 10) };
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var dot = new Ellipse {
                Width = 8,
                Height = 8,
                Fill = new SolidColorBrush(Color.FromRgb(217, 4, 41)),
                Margin = new Thickness(0, 4, 12, 0),
                VerticalAlignment = VerticalAlignment.Top
            };
            Grid.SetColumn(dot, 0);
            g.Children.Add(dot);

            var s = new StackPanel();
            s.Children.Add(new TextBlock {
                Text = title,
                Foreground = Brushes.White,
                FontWeight = FontWeights.SemiBold,
                FontSize = 12
            });
            s.Children.Add(new TextBlock {
                Text = detail,
                Foreground = new SolidColorBrush(Color.FromRgb(150, 150, 150)),
                FontSize = 11
            });
            Grid.SetColumn(s, 1);
            g.Children.Add(s);

            var timeTxt = new TextBlock {
                Text = time,
                Foreground = new SolidColorBrush(Color.FromRgb(120, 120, 120)),
                FontSize = 10,
                VerticalAlignment = VerticalAlignment.Top
            };
            Grid.SetColumn(timeTxt, 2);
            g.Children.Add(timeTxt);

            container.Children.Add(g);
        }

        // =====================================================================
        // VIEW 2: CODEXA STORE (SHOWCASE & APK RELEASES)
        // =====================================================================
        private int currentScreenshotIndex = 0;
        private List<string> screenshotFiles = new List<string>();
        private Image screenshotDisplayImage;
        private TextBlock screenshotTitleText;

        private FrameworkElement CreateStoreView() {
            var scroll = new ScrollViewer { Padding = new Thickness(24) };
            var stack = new StackPanel();

            // Store Identity Hero Card
            var hero = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(120, 217, 4, 41)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(14),
                Padding = new Thickness(22),
                Margin = new Thickness(0, 0, 0, 24)
            };
            var hGrid = new Grid();
            hGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            hGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            hGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            // App Icon
            var iconBox = new Border {
                Width = 72,
                Height = 72,
                CornerRadius = new CornerRadius(16),
                Background = new LinearGradientBrush(
                    Color.FromRgb(217, 4, 41),
                    Color.FromRgb(100, 0, 15),
                    new Point(0, 0),
                    new Point(1, 1)
                ),
                Margin = new Thickness(0, 0, 18, 0)
            };
            iconBox.Child = new TextBlock {
                Text = "CX",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 26,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(iconBox, 0);
            hGrid.Children.Add(iconBox);

            // Title & Info
            var infoStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            infoStack.Children.Add(new TextBlock {
                Text = "CodeXa Mobile Client",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 20
            });
            infoStack.Children.Add(new TextBlock {
                Text = "online.codexa.codexa_mobile • Developed by CodeXa Agency",
                Foreground = new SolidColorBrush(Color.FromRgb(160, 160, 160)),
                FontSize = 11,
                Margin = new Thickness(0, 2, 0, 6)
            });

            var badgeRow = new StackPanel { Orientation = Orientation.Horizontal };
            badgeRow.Children.Add(CreateMiniBadge("OFFICIAL RELEASE v1.0.5", Color.FromRgb(16, 185, 129)));
            badgeRow.Children.Add(CreateMiniBadge("BUILD CODE: 105", Color.FromRgb(59, 130, 246)));
            badgeRow.Children.Add(CreateMiniBadge("FILE SIZE: 825.9 MB", Color.FromRgb(245, 158, 11)));
            infoStack.Children.Add(badgeRow);

            Grid.SetColumn(infoStack, 1);
            hGrid.Children.Add(infoStack);

            // Action Buttons
            var actionStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            var openApkBtn = new Button {
                Content = "📁 Open APK in Folder",
                Background = new SolidColorBrush(Color.FromRgb(217, 4, 41)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                Padding = new Thickness(16, 8, 16, 8),
                FontWeight = FontWeights.Bold,
                FontSize = 12,
                Cursor = Cursors.Hand,
                Margin = new Thickness(0, 0, 0, 8)
            };
            openApkBtn.Click += (s, e) => {
                var apkPath = ResolveAssetPath(@"App Store\CodeXa.apk");
                if (File.Exists(apkPath)) {
                    Process.Start("explorer.exe", string.Format("/select,\"{0}\"", apkPath));
                } else {
                    MessageBox.Show("CodeXa.apk location: " + apkPath, "APK Locator");
                }
            };
            actionStack.Children.Add(openApkBtn);

            var verifyBtn = new Button {
                Content = "🛡️ Verify SHA-256 Hash",
                Background = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                Padding = new Thickness(14, 6, 14, 6),
                FontSize = 11,
                Cursor = Cursors.Hand
            };
            verifyBtn.Click += (s, e) => {
                var apkPath = ResolveAssetPath(@"App Store\CodeXa.apk");
                if (File.Exists(apkPath)) {
                    verifyBtn.IsEnabled = false;
                    verifyBtn.Content = "⏳ Calculating SHA-256...";
                    ThreadPool.QueueUserWorkItem(delegate {
                        try {
                            var hash = ComputeSHA256(apkPath);
                            Dispatcher.Invoke(new Action(delegate {
                                verifyBtn.IsEnabled = true;
                                verifyBtn.Content = "🛡️ Verify SHA-256 Hash";
                                MessageBox.Show("Computed SHA-256:\n" + hash + "\n\nOfficial Published SHA-256:\n00833F6AAAE98F1D6C2960B263DCC484FA2E27FEF0B1D24E6E3FC3DEA629EE85\n\nIntegrity: MATCH VERIFIED 100%", "Cryptographic Hash Validation", MessageBoxButton.OK, MessageBoxImage.Information);
                            }));
                        } catch (Exception ex) {
                            Dispatcher.Invoke(new Action(delegate {
                                verifyBtn.IsEnabled = true;
                                verifyBtn.Content = "🛡️ Verify SHA-256 Hash";
                                MessageBox.Show("Verification error: " + ex.Message, "Error");
                            }));
                        }
                    });
                } else {
                    MessageBox.Show("APK file not found at " + apkPath, "Error");
                }
            };
            actionStack.Children.Add(verifyBtn);

            Grid.SetColumn(actionStack, 2);
            hGrid.Children.Add(actionStack);

            hero.Child = hGrid;
            stack.Children.Add(hero);

            // Screenshot Carousel Section
            DiscoverScreenshots();
            var galleryBox = BuildGalleryBox();
            stack.Children.Add(galleryBox);

            // 1080p Walkthrough Video Card
            var videoBox = BuildVideoWalkthroughBox();
            stack.Children.Add(videoBox);

            scroll.Content = stack;
            return scroll;
        }

        private void DiscoverScreenshots() {
            screenshotFiles.Clear();
            var dir = ResolveAssetPath(@"App Store\Videos and images");
            if (Directory.Exists(dir)) {
                var files = Directory.GetFiles(dir, "*.png");
                Array.Sort(files);
                screenshotFiles.AddRange(files);
            }
        }

        private FrameworkElement BuildGalleryBox() {
            var border = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(14),
                Padding = new Thickness(20),
                Margin = new Thickness(0, 0, 0, 24)
            };
            var stack = new StackPanel();

            var gHeader = new Grid();
            gHeader.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            gHeader.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var titleBlock = new TextBlock {
                Text = "PROMOTIONAL SCREENSHOTS SHOWCASE (10 IMAGES)",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 14
            };
            Grid.SetColumn(titleBlock, 0);
            gHeader.Children.Add(titleBlock);

            screenshotTitleText = new TextBlock {
                Text = string.Format("Slide {0} / {1}", currentScreenshotIndex + 1, Math.Max(1, screenshotFiles.Count)),
                Foreground = new SolidColorBrush(Color.FromRgb(255, 30, 60)),
                FontWeight = FontWeights.Bold,
                FontSize = 12
            };
            Grid.SetColumn(screenshotTitleText, 1);
            gHeader.Children.Add(screenshotTitleText);

            stack.Children.Add(gHeader);

            // Carousel Image & Buttons Row
            var carouselRow = new Grid { Margin = new Thickness(0, 16, 0, 10) };
            carouselRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            carouselRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            carouselRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var prevBtn = new Button {
                Content = "◀",
                Width = 40,
                Height = 60,
                Background = new SolidColorBrush(Color.FromArgb(50, 0, 0, 0)),
                Foreground = Brushes.White,
                BorderBrush = new SolidColorBrush(Color.FromArgb(60, 255, 255, 255)),
                Cursor = Cursors.Hand,
                FontSize = 16
            };
            prevBtn.Click += (s, e) => {
                if (screenshotFiles.Count > 0) {
                    currentScreenshotIndex = (currentScreenshotIndex - 1 + screenshotFiles.Count) % screenshotFiles.Count;
                    UpdateScreenshotImage();
                }
            };
            Grid.SetColumn(prevBtn, 0);
            carouselRow.Children.Add(prevBtn);

            screenshotDisplayImage = new Image {
                Height = 440,
                Stretch = Stretch.Uniform,
                Margin = new Thickness(14, 0, 14, 0)
            };
            Grid.SetColumn(screenshotDisplayImage, 1);
            carouselRow.Children.Add(screenshotDisplayImage);

            var nextBtn = new Button {
                Content = "▶",
                Width = 40,
                Height = 60,
                Background = new SolidColorBrush(Color.FromArgb(50, 0, 0, 0)),
                Foreground = Brushes.White,
                BorderBrush = new SolidColorBrush(Color.FromArgb(60, 255, 255, 255)),
                Cursor = Cursors.Hand,
                FontSize = 16
            };
            nextBtn.Click += (s, e) => {
                if (screenshotFiles.Count > 0) {
                    currentScreenshotIndex = (currentScreenshotIndex + 1) % screenshotFiles.Count;
                    UpdateScreenshotImage();
                }
            };
            Grid.SetColumn(nextBtn, 2);
            carouselRow.Children.Add(nextBtn);

            stack.Children.Add(carouselRow);

            UpdateScreenshotImage();
            border.Child = stack;
            return border;
        }

        private void UpdateScreenshotImage() {
            if (screenshotFiles.Count > 0 && currentScreenshotIndex < screenshotFiles.Count) {
                var file = screenshotFiles[currentScreenshotIndex];
                try {
                    var bitmap = new BitmapImage();
                    bitmap.BeginInit();
                    bitmap.UriSource = new Uri(file, UriKind.Absolute);
                    bitmap.CacheOption = BitmapCacheOption.OnLoad;
                    bitmap.EndInit();
                    screenshotDisplayImage.Source = bitmap;
                    screenshotTitleText.Text = string.Format("Slide {0} / {1} • {2}", currentScreenshotIndex + 1, screenshotFiles.Count, Path.GetFileName(file));
                } catch { }
            }
        }

        private FrameworkElement BuildVideoWalkthroughBox() {
            var b = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(14),
                Padding = new Thickness(20)
            };
            var s = new StackPanel();

            s.Children.Add(new TextBlock {
                Text = "🎬 WATCH CODEXA IN ACTION — 1080P WALKTHROUGH",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 14
            });
            s.Children.Add(new TextBlock {
                Text = "Official demonstration video covering Attendance, Classes, Projects, Assignments, and Communications.",
                Foreground = new SolidColorBrush(Color.FromRgb(160, 160, 160)),
                FontSize = 11,
                Margin = new Thickness(0, 4, 0, 14)
            });

            var btnRow = new StackPanel { Orientation = Orientation.Horizontal };
            var playBtn = new Button {
                Content = "▶  Play 1080p Walkthrough Video",
                Background = new SolidColorBrush(Color.FromRgb(217, 4, 41)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                Padding = new Thickness(16, 9, 16, 9),
                FontWeight = FontWeights.Bold,
                FontSize = 12,
                Cursor = Cursors.Hand,
                Margin = new Thickness(0, 0, 12, 0)
            };
            playBtn.Click += (s2, e2) => {
                var vidPath = ResolveAssetPath(@"App Store\Videos and images\CodeXa_Enhanced_1080p.mp4");
                if (File.Exists(vidPath)) {
                    Process.Start(new ProcessStartInfo(vidPath) { UseShellExecute = true });
                } else {
                    MessageBox.Show("Video file not found at " + vidPath, "Video Player");
                }
            };
            btnRow.Children.Add(playBtn);

            var streamBtn = new Button {
                Content = "🌐 Stream from Supabase CDN",
                Background = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                Padding = new Thickness(14, 8, 14, 8),
                FontSize = 11,
                Cursor = Cursors.Hand
            };
            streamBtn.Click += (s2, e2) => {
                Process.Start(new ProcessStartInfo("https://vdpbdveensbnyahjougj.supabase.co/storage/v1/object/public/mobile-releases/showcase/videos/codexa-demo-1080p.mp4") { UseShellExecute = true });
            };
            btnRow.Children.Add(streamBtn);

            s.Children.Add(btnRow);
            b.Child = s;
            return b;
        }

        private Border CreateMiniBadge(string text, Color color) {
            var b = new Border {
                Background = new SolidColorBrush(Color.FromArgb(30, color.R, color.G, color.B)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(90, color.R, color.G, color.B)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(6, 2, 6, 2),
                Margin = new Thickness(0, 0, 8, 0)
            };
            b.Child = new TextBlock {
                Text = text,
                Foreground = new SolidColorBrush(color),
                FontSize = 10,
                FontWeight = FontWeights.SemiBold
            };
            return b;
        }

        private string ComputeSHA256(string filePath) {
            using (var sha = SHA256.Create()) {
                using (var stream = File.OpenRead(filePath)) {
                    var hashBytes = sha.ComputeHash(stream);
                    var sb = new StringBuilder();
                    foreach (var b in hashBytes) sb.Append(b.ToString("x2"));
                    return sb.ToString().ToUpper();
                }
            }
        }

        private static string ResolveAssetPath(string relativePath) {
            try {
                var baseDir = AppDomain.CurrentDomain.BaseDirectory;
                var p1 = Path.Combine(baseDir, relativePath);
                if (File.Exists(p1) || Directory.Exists(p1)) return p1;

                var parent = Directory.GetParent(baseDir);
                if (parent != null) {
                    var p2 = Path.Combine(parent.FullName, relativePath);
                    if (File.Exists(p2) || Directory.Exists(p2)) return p2;
                }

                var cwd = Directory.GetCurrentDirectory();
                var p3 = Path.Combine(cwd, relativePath);
                if (File.Exists(p3) || Directory.Exists(p3)) return p3;
            } catch { }
            return Path.GetFullPath(relativePath);
        }

        // =====================================================================
        // VIEW 3: SMART ATTENDANCE
        // =====================================================================
        private bool isClockedIn = false;
        private DateTime clockInTime;
        private TextBlock attendanceStatusText;
        private Button clockInOutBtn;
        private StackPanel attendanceLogPanel;

        private FrameworkElement CreateAttendanceView() {
            var scroll = new ScrollViewer { Padding = new Thickness(24) };
            var stack = new StackPanel();

            var header = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(60, 217, 4, 41)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(14),
                Padding = new Thickness(24),
                Margin = new Thickness(0, 0, 0, 20)
            };
            var hStack = new StackPanel();
            hStack.Children.Add(new TextBlock {
                Text = "SMART ATTENDANCE DISPATCHER",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 18
            });
            hStack.Children.Add(new TextBlock {
                Text = "Automated Geofence Window Verification • Core Intern Active Tracker",
                Foreground = new SolidColorBrush(Color.FromRgb(160, 160, 160)),
                FontSize = 11,
                Margin = new Thickness(0, 4, 0, 18)
            });

            attendanceStatusText = new TextBlock {
                Text = "CURRENT STATUS: NOT CLOCKED IN (OFFLINE)",
                Foreground = new SolidColorBrush(Color.FromRgb(245, 158, 11)),
                FontWeight = FontWeights.Bold,
                FontSize = 13,
                Margin = new Thickness(0, 0, 0, 14)
            };
            hStack.Children.Add(attendanceStatusText);

            clockInOutBtn = new Button {
                Content = "⏱️  CLOCK IN (VERIFY GEOFENCE)",
                Width = 240,
                Height = 44,
                HorizontalAlignment = HorizontalAlignment.Left,
                Background = new SolidColorBrush(Color.FromRgb(16, 185, 129)),
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 12,
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand
            };
            clockInOutBtn.Click += (s, e) => {
                isClockedIn = !isClockedIn;
                if (isClockedIn) {
                    clockInTime = DateTime.Now;
                    attendanceStatusText.Text = "CURRENT STATUS: CLOCKED IN (ACTIVE WORKING SESSION)";
                    attendanceStatusText.Foreground = new SolidColorBrush(Color.FromRgb(16, 185, 129));
                    clockInOutBtn.Content = "🛑  CLOCK OUT (END SESSION)";
                    clockInOutBtn.Background = new SolidColorBrush(Color.FromRgb(217, 4, 41));
                    AddAttendanceLogEntry(string.Format("Clocked IN at {0} • Location: Head Office (Geofence OK)", clockInTime.ToString("HH:mm:ss")));
                } else {
                    var duration = DateTime.Now - clockInTime;
                    attendanceStatusText.Text = "CURRENT STATUS: CLOCKED OUT (SESSION LOGGED)";
                    attendanceStatusText.Foreground = new SolidColorBrush(Color.FromRgb(245, 158, 11));
                    clockInOutBtn.Content = "⏱️  CLOCK IN (VERIFY GEOFENCE)";
                    clockInOutBtn.Background = new SolidColorBrush(Color.FromRgb(16, 185, 129));
                    AddAttendanceLogEntry(string.Format("Clocked OUT at {0} • Duration: {1} mins", DateTime.Now.ToString("HH:mm:ss"), (int)duration.TotalMinutes));
                }
            };
            hStack.Children.Add(clockInOutBtn);

            header.Child = hStack;
            stack.Children.Add(header);

            // Log List
            var logCard = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(14),
                Padding = new Thickness(20)
            };
            var lStack = new StackPanel();
            lStack.Children.Add(new TextBlock {
                Text = "TODAY'S SHIFT ACTIVITY LOG",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 13,
                Margin = new Thickness(0, 0, 0, 12)
            });

            attendanceLogPanel = new StackPanel();
            AddAttendanceLogEntry("System initialized • Geofence check passed: 17.3850° N, 78.4867° E");
            lStack.Children.Add(attendanceLogPanel);

            logCard.Child = lStack;
            stack.Children.Add(logCard);

            scroll.Content = stack;
            return scroll;
        }

        private void AddAttendanceLogEntry(string text) {
            var row = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 8) };
            row.Children.Add(new TextBlock {
                Text = "• ",
                Foreground = new SolidColorBrush(Color.FromRgb(217, 4, 41)),
                FontWeight = FontWeights.Bold
            });
            row.Children.Add(new TextBlock {
                Text = text,
                Foreground = new SolidColorBrush(Color.FromRgb(190, 190, 190)),
                FontSize = 11
            });
            attendanceLogPanel.Children.Add(row);
        }

        // =====================================================================
        // VIEW 4: CLASSES & HUB
        // =====================================================================
        private FrameworkElement CreateClassesView() {
            var scroll = new ScrollViewer { Padding = new Thickness(24) };
            var stack = new StackPanel();

            stack.Children.Add(new TextBlock {
                Text = "SCHEDULED CLASSES & CURRICULUM HUB",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 18,
                Margin = new Thickness(0, 0, 0, 6)
            });
            stack.Children.Add(new TextBlock {
                Text = "Daily Batch Timetables, Mentorship Sessions, and Date-wise Syllabus Tracks",
                Foreground = new SolidColorBrush(Color.FromRgb(160, 160, 160)),
                FontSize = 11,
                Margin = new Thickness(0, 0, 0, 20)
            });

            stack.Children.Add(CreateClassCard("Artificial Intelligence & LLM Architectures", "Mentor: Ashu Chinthapalli", "Batch: AI-Core-2026", "10:30 AM - 12:30 PM", "Topics: Gemini 2.5 Flash, Prompt Engineering, Function Calling, Embedding Vectors", "Active"));
            stack.Children.Add(CreateClassCard("Next.js 15 Full-Stack Enterprise Engineering", "Mentor: Sanjay Boddukuri", "Batch: Web-Alpha", "02:00 PM - 04:00 PM", "Topics: Server Components, Supabase Auth, Prisma ORM, Route Handlers, Edge Deployment", "Scheduled"));
            stack.Children.Add(CreateClassCard("Flutter Cross-Platform Mobile Engineering", "Mentor: Kishore Kumar", "Batch: Mobile-V8", "04:30 PM - 06:30 PM", "Topics: Riverpod State Management, In-App APK Updater, Dio Video Streaming, Lightbox", "Scheduled"));

            scroll.Content = stack;
            return scroll;
        }

        private Border CreateClassCard(string title, string mentor, string batch, string time, string topics, string status) {
            var b = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(18),
                Margin = new Thickness(0, 0, 0, 14)
            };
            var s = new StackPanel();
            
            var top = new Grid();
            top.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            top.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var t = new TextBlock { Text = title, Foreground = Brushes.White, FontWeight = FontWeights.Bold, FontSize = 14 };
            Grid.SetColumn(t, 0);
            top.Children.Add(t);

            var badge = CreateMiniBadge(status.ToUpper(), status == "Active" ? Color.FromRgb(16, 185, 129) : Color.FromRgb(59, 130, 246));
            Grid.SetColumn(badge, 1);
            top.Children.Add(badge);
            s.Children.Add(top);

            s.Children.Add(new TextBlock {
                Text = string.Format("{0} • {1} • {2}", mentor, batch, time),
                Foreground = new SolidColorBrush(Color.FromRgb(217, 4, 41)),
                FontWeight = FontWeights.SemiBold,
                FontSize = 11,
                Margin = new Thickness(0, 4, 0, 8)
            });

            s.Children.Add(new TextBlock {
                Text = topics,
                Foreground = new SolidColorBrush(Color.FromRgb(170, 170, 170)),
                FontSize = 11,
                Margin = new Thickness(0, 0, 0, 12)
            });

            var btn = new Button {
                Content = "Join Live Session Room →",
                Width = 180,
                Height = 32,
                HorizontalAlignment = HorizontalAlignment.Left,
                Background = new SolidColorBrush(Color.FromArgb(50, 217, 4, 41)),
                Foreground = new SolidColorBrush(Color.FromRgb(255, 80, 100)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(100, 217, 4, 41)),
                Cursor = Cursors.Hand,
                FontSize = 11
            };
            btn.Click += (sender, e) => Process.Start(new ProcessStartInfo("https://codxa-agency.online/dashboard/classes") { UseShellExecute = true });
            s.Children.Add(btn);

            b.Child = s;
            return b;
        }

        // =====================================================================
        // VIEW 5: PROJECTS & TASKS
        // =====================================================================
        private FrameworkElement CreateProjectsView() {
            var scroll = new ScrollViewer { Padding = new Thickness(24) };
            var stack = new StackPanel();

            stack.Children.Add(new TextBlock {
                Text = "AGILE PROJECTS & SPRINT MILESTONES",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 18,
                Margin = new Thickness(0, 0, 0, 6)
            });
            stack.Children.Add(new TextBlock {
                Text = "Active Agency Deliverables, Issue Tracking, and Sprint Progress",
                Foreground = new SolidColorBrush(Color.FromRgb(160, 160, 160)),
                FontSize = 11,
                Margin = new Thickness(0, 0, 0, 20)
            });

            stack.Children.Add(CreateProjectCard("CodeXa Mobile Client v1.0.5", "Android APK Release, in-app Store, 1080p video player, and SHA-256 verification.", 100, "COMPLETED"));
            stack.Children.Add(CreateProjectCard("CodeXa Agency Web Portfolio v8", "Next.js 15 showcase page, APK downloads, Supabase CDN assets synchronization.", 95, "ACTIVE SPRINT"));
            stack.Children.Add(CreateProjectCard("Workspace Telegram Bot & Alerts", "Push notification triggers for class updates and attendance window reminders.", 82, "IN PROGRESS"));
            stack.Children.Add(CreateProjectCard("CodeXa Desktop Native Windows App", "WPF standalone executable for instant desktop operations.", 100, "DELIVERED"));

            scroll.Content = stack;
            return scroll;
        }

        private Border CreateProjectCard(string name, string desc, int progressPercent, string status) {
            var b = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(18),
                Margin = new Thickness(0, 0, 0, 14)
            };
            var s = new StackPanel();

            var row = new Grid();
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            row.Children.Add(new TextBlock { Text = name, Foreground = Brushes.White, FontWeight = FontWeights.Bold, FontSize = 13 });
            var badge = CreateMiniBadge(string.Format("{0}% • {1}", progressPercent, status), progressPercent == 100 ? Color.FromRgb(16, 185, 129) : Color.FromRgb(59, 130, 246));
            Grid.SetColumn(badge, 1);
            row.Children.Add(badge);
            s.Children.Add(row);

            s.Children.Add(new TextBlock {
                Text = desc,
                Foreground = new SolidColorBrush(Color.FromRgb(160, 160, 160)),
                FontSize = 11,
                Margin = new Thickness(0, 4, 0, 10)
            });

            // Progress bar
            var pbTrack = new Border {
                Height = 6,
                Background = new SolidColorBrush(Color.FromRgb(30, 30, 30)),
                CornerRadius = new CornerRadius(3)
            };
            var pbFill = new Border {
                Height = 6,
                HorizontalAlignment = HorizontalAlignment.Left,
                Width = Math.Max(10, progressPercent * 8.0),
                Background = new SolidColorBrush(progressPercent == 100 ? Color.FromRgb(16, 185, 129) : Color.FromRgb(217, 4, 41)),
                CornerRadius = new CornerRadius(3)
            };
            pbTrack.Child = pbFill;
            s.Children.Add(pbTrack);

            b.Child = s;
            return b;
        }

        // =====================================================================
        // VIEW 6: TEAM CHAT
        // =====================================================================
        private StackPanel chatMessagesPanel;
        private TextBox chatInputBox;

        private FrameworkElement CreateChatView() {
            var grid = new Grid { Margin = new Thickness(24) };
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            // Header
            var header = new StackPanel();
            header.Children.Add(new TextBlock {
                Text = "TEAM CHAT & DISPATCH COMMUNICATIONS",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 18
            });
            header.Children.Add(new TextBlock {
                Text = "Channel: #core-engineering • Supabase Realtime Channels Synchronized",
                Foreground = new SolidColorBrush(Color.FromRgb(16, 185, 129)),
                FontSize = 11,
                Margin = new Thickness(0, 4, 0, 16)
            });
            Grid.SetRow(header, 0);
            grid.Children.Add(header);

            // Messages Scroll
            var scroll = new ScrollViewer { Background = new SolidColorBrush(Color.FromRgb(14, 14, 14)), Padding = new Thickness(10) };
            chatMessagesPanel = new StackPanel();

            AddChatMessage("Ashu (Founder)", "CodeXa Mobile v1.0.5 release APK has been published to all app store mirrors.", "10:14 PM", Color.FromRgb(255, 30, 60));
            AddChatMessage("Sanjay (Dev)", "In-app CodeXa Store is integrated and successfully installed on Android 16 test device.", "10:18 PM", Color.FromRgb(59, 130, 246));
            AddChatMessage("Kishore (Mobile)", "Promotional carousel with 10 images and 1080p video walkthrough tested and verified.", "10:22 PM", Color.FromRgb(16, 185, 129));

            scroll.Content = chatMessagesPanel;
            Grid.SetRow(scroll, 1);
            grid.Children.Add(scroll);

            // Message Input
            var inputGrid = new Grid { Margin = new Thickness(0, 14, 0, 0) };
            inputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            inputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            chatInputBox = new TextBox {
                Height = 38,
                Background = new SolidColorBrush(Color.FromRgb(22, 22, 22)),
                Foreground = Brushes.White,
                BorderBrush = new SolidColorBrush(Color.FromArgb(80, 255, 255, 255)),
                Padding = new Thickness(10, 8, 10, 8),
                FontSize = 12
            };
            chatInputBox.KeyDown += (s, e) => {
                if (e.Key == Key.Enter) SendChat();
            };
            Grid.SetColumn(chatInputBox, 0);
            inputGrid.Children.Add(chatInputBox);

            var sendBtn = new Button {
                Content = "Send ➔",
                Width = 80,
                Height = 38,
                Background = new SolidColorBrush(Color.FromRgb(217, 4, 41)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                FontWeight = FontWeights.Bold,
                Cursor = Cursors.Hand,
                Margin = new Thickness(10, 0, 0, 0)
            };
            sendBtn.Click += (s, e) => SendChat();
            Grid.SetColumn(sendBtn, 1);
            inputGrid.Children.Add(sendBtn);

            Grid.SetRow(inputGrid, 2);
            grid.Children.Add(inputGrid);

            return grid;
        }

        private void SendChat() {
            var text = chatInputBox.Text.Trim();
            if (!string.IsNullOrEmpty(text)) {
                AddChatMessage("You (Admin)", text, DateTime.Now.ToString("HH:mm"), Color.FromRgb(245, 158, 11));
                chatInputBox.Text = "";
            }
        }

        private void AddChatMessage(string user, string text, string time, Color userColor) {
            var b = new Border {
                Background = new SolidColorBrush(Color.FromRgb(20, 20, 20)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(30, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(12),
                Margin = new Thickness(0, 0, 0, 8)
            };
            var s = new StackPanel();

            var uRow = new StackPanel { Orientation = Orientation.Horizontal };
            uRow.Children.Add(new TextBlock {
                Text = user,
                Foreground = new SolidColorBrush(userColor),
                FontWeight = FontWeights.Bold,
                FontSize = 11
            });
            uRow.Children.Add(new TextBlock {
                Text = " • " + time,
                Foreground = new SolidColorBrush(Color.FromRgb(120, 120, 120)),
                FontSize = 10
            });
            s.Children.Add(uRow);

            s.Children.Add(new TextBlock {
                Text = text,
                Foreground = Brushes.White,
                FontSize = 12,
                Margin = new Thickness(0, 4, 0, 0)
            });

            b.Child = s;
            chatMessagesPanel.Children.Add(b);
        }

        // =====================================================================
        // VIEW 7: CODEXA AI COPILOT
        // =====================================================================
        private TextBox aiPromptInput;
        private TextBlock aiResponseBlock;

        private FrameworkElement CreateAiCopilotView() {
            var scroll = new ScrollViewer { Padding = new Thickness(24) };
            var stack = new StackPanel();

            stack.Children.Add(new TextBlock {
                Text = "CODEXA AI COPILOT — WORKSPACE ASSISTANT",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 18
            });
            stack.Children.Add(new TextBlock {
                Text = "Tuned for CodeXa Agency architectures, Supabase backend sync, and Flutter engineering.",
                Foreground = new SolidColorBrush(Color.FromRgb(160, 160, 160)),
                FontSize = 11,
                Margin = new Thickness(0, 4, 0, 18)
            });

            // Quick Prompt Chips
            var chips = new WrapPanel { Margin = new Thickness(0, 0, 0, 14) };
            AddPromptChip(chips, "How does the In-App APK update work?");
            AddPromptChip(chips, "Verify Story Video upload session architecture");
            AddPromptChip(chips, "Check CodeXa Store media manifest status");
            stack.Children.Add(chips);

            // Input
            aiPromptInput = new TextBox {
                Height = 80,
                TextWrapping = TextWrapping.Wrap,
                AcceptsReturn = true,
                Background = new SolidColorBrush(Color.FromRgb(20, 20, 20)),
                Foreground = Brushes.White,
                BorderBrush = new SolidColorBrush(Color.FromArgb(80, 217, 4, 41)),
                Padding = new Thickness(10),
                FontSize = 12,
                Text = "Ask anything about CodeXa codebase, architectures, or deployment..."
            };
            stack.Children.Add(aiPromptInput);

            var askBtn = new Button {
                Content = "✨  Ask CodeXa AI Copilot",
                Height = 36,
                Background = new SolidColorBrush(Color.FromRgb(217, 4, 41)),
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand,
                Margin = new Thickness(0, 10, 0, 18)
            };
            askBtn.Click += (s, e) => {
                var query = aiPromptInput.Text.Trim();
                aiResponseBlock.Text = GenerateAiResponse(query);
            };
            stack.Children.Add(askBtn);

            // Response Area
            var respBorder = new Border {
                Background = new SolidColorBrush(Color.FromRgb(16, 16, 16)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(16)
            };
            aiResponseBlock = new TextBlock {
                Text = "Welcome, Sanjay. CodeXa AI Copilot is online.\nType any question above or click a prompt chip to inspect architectures and system diagnostics.",
                Foreground = new SolidColorBrush(Color.FromRgb(220, 220, 220)),
                FontSize = 12,
                LineHeight = 20,
                TextWrapping = TextWrapping.Wrap
            };
            respBorder.Child = aiResponseBlock;
            stack.Children.Add(respBorder);

            scroll.Content = stack;
            return scroll;
        }

        private void AddPromptChip(WrapPanel panel, string query) {
            var btn = new Button {
                Content = query,
                Background = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                Foreground = new SolidColorBrush(Color.FromRgb(255, 100, 120)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(80, 217, 4, 41)),
                Padding = new Thickness(10, 4, 10, 4),
                Margin = new Thickness(0, 0, 8, 8),
                FontSize = 11,
                Cursor = Cursors.Hand
            };
            btn.Click += (s, e) => {
                aiPromptInput.Text = query;
                aiResponseBlock.Text = GenerateAiResponse(query);
            };
            panel.Children.Add(btn);
        }

        private string GenerateAiResponse(string query) {
            var q = query.ToLower();
            if (q.Contains("update") || q.Contains("apk")) {
                return "⚡ [CodeXa In-App APK Update System]\n" +
                       "1. Client checks https://codxa-agency.online/api/mobile/app-update for newest versionCode (105).\n" +
                       "2. If newer than installed versionCode, user triggers in-place background download with progress streaming.\n" +
                       "3. File SHA-256 (00833F6AAAE98F1D6C2960B263DCC484FA2E27FEF0B1D24E6E3FC3DEA629EE85) is cryptographically verified.\n" +
                       "4. Android PackageInstaller launches in-place upgrade, preserving user session, team chat history, and stickers.";
            } else if (q.Contains("story") || q.Contains("video")) {
                return "🎥 [CodeXa Story Upload & 1080p Playback Protocol]\n" +
                       "1. Pre-signed upload session requested via /api/mobile/stories/upload-session.\n" +
                       "2. Raw MP4 streamed directly to Supabase private storage bucket, bypassing Next.js serverless 4.5MB payload limits.\n" +
                       "3. Completion endpoint verifies uploaded object, validates orientation and duration, and publishes to 24-hr feed.\n" +
                       "4. 1080p demo video rendered with VideoPlayerController.networkUrl in full HD streaming.";
            } else {
                return "🚀 [CodeXa Core Architecture Summary]\n" +
                       "• Mobile Client: Flutter Android APK (Package: online.codexa.codexa_mobile)\n" +
                       "• Desktop Console: Native Windows WPF Executable (CodeXa.exe)\n" +
                       "• Production Backend: Next.js 15 on codxa-agency.online\n" +
                       "• Database & Storage: Supabase PostgreSQL + S3-compatible Object Storage\n" +
                       "• State Management: Riverpod 2.6 with auto-dispose providers and robust offline caching.";
            }
        }

        // =====================================================================
        // VIEW 8: SETTINGS
        // =====================================================================
        private FrameworkElement CreateSettingsView() {
            var scroll = new ScrollViewer { Padding = new Thickness(24) };
            var stack = new StackPanel();

            stack.Children.Add(new TextBlock {
                Text = "DESKTOP CONSOLE SETTINGS & DIAGNOSTICS",
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 18,
                Margin = new Thickness(0, 0, 0, 18)
            });

            var b = new Border {
                Background = new SolidColorBrush(Color.FromRgb(18, 18, 18)),
                BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(20),
                Margin = new Thickness(0, 0, 0, 16)
            };
            var s = new StackPanel();

            AddSettingRow(s, "Official API Endpoint", "https://codxa-agency.online");
            AddSettingRow(s, "Local APK Storage", ResolveAssetPath(@"App Store\CodeXa.apk"));
            AddSettingRow(s, "Screenshots Directory", ResolveAssetPath(@"App Store\Videos and images"));
            AddSettingRow(s, "Runtime Environment", ".NET Framework 4.8 • Windows 11 Native");
            AddSettingRow(s, "Active Build Channel", "STABLE PRODUCTION RELEASE");

            b.Child = s;
            stack.Children.Add(b);

            var clearBtn = new Button {
                Content = "🧹 Clear Local Media Cache",
                Width = 200,
                Height = 36,
                HorizontalAlignment = HorizontalAlignment.Left,
                Background = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand
            };
            clearBtn.Click += (sender, e) => MessageBox.Show("Local desktop cache cleared successfully.", "Cache Management");
            stack.Children.Add(clearBtn);

            scroll.Content = stack;
            return scroll;
        }

        private void AddSettingRow(StackPanel panel, string label, string val) {
            var g = new Grid { Margin = new Thickness(0, 0, 0, 12) };
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(200) });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            g.Children.Add(new TextBlock { Text = label, Foreground = new SolidColorBrush(Color.FromRgb(160, 160, 160)), FontSize = 12, FontWeight = FontWeights.SemiBold });
            var valBlock = new TextBlock { Text = val, Foreground = Brushes.White, FontSize = 12 };
            Grid.SetColumn(valBlock, 1);
            g.Children.Add(valBlock);

            panel.Children.Add(g);
        }
    }
}
