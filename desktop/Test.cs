using System;
using System.Windows;

namespace CodeXaDesktop {
    public class Program {
        [STAThread]
        public static void Main() {
            var app = new Application();
            var window = new Window {
                Title = "CodeXa Test",
                Width = 400,
                Height = 300
            };
            // Just test compilation
        }
    }
}
