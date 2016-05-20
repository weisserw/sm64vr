using System;
using System.Reflection;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;

namespace BMPToPNG {
    class Program {
        static int Main(string[] args) {
            try {
#if DEBUG
                var startpath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) + @"\..\..\..";
                var transpath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) + @"\..\..\..\transparent.txt";
#else
                var startpath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                var transpath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) + @"\transparent.txt";
#endif
                var transparent = new Dictionary<string, Color>();

                using (StreamReader sr = new StreamReader(transpath, Encoding.ASCII)) {
                    string line;
                    while ((line = sr.ReadLine()) != null) {
                        var c = line.Split(',');
                        transparent[c[0]] = Color.FromArgb(int.Parse(c[1]), int.Parse(c[2]), int.Parse(c[3]));
                    }
                }

                foreach (string file in Directory.EnumerateFiles(startpath, "*.bmp", SearchOption.AllDirectories)) {
                    var bmp = new Bitmap(file);
                    string pngname = Path.GetDirectoryName(file) + @"\" + Path.GetFileNameWithoutExtension(file) + ".png";
                    bmp.Save(pngname, ImageFormat.Png);

                    var fc = file.Split('\\');
                    if (fc.Length > 1) {
                        var p = string.Format(@"{0}\{1}", fc[fc.Length - 2], fc[fc.Length - 1]).ToLower();
                        if (transparent.ContainsKey(p)) {
                            Bitmap png;
                            using (FileStream fs = new FileStream(pngname, FileMode.Open, FileAccess.Read)) {
                                png = new Bitmap(fs);

                                var keycolor = transparent[p];

                                for (int x = 0; x < bmp.Width; x++) {
                                    for (int y = 0; y < bmp.Height; y++) {
                                        var c = png.GetPixel(x, y);
                                        if (c.R == keycolor.R && c.G == keycolor.G && c.B == keycolor.B) {
                                            png.SetPixel(x, y, Color.FromArgb(0, c));
                                        }
                                    }
                                }
                            }
                            png.Save(pngname, ImageFormat.Png);
                        }
                    }
                }
            } catch (Exception e) {
                Console.Error.WriteLine(e.ToString());
                return 1;
            }
            return 0;
        }
    }
}
