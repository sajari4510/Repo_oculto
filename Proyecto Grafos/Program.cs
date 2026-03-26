using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
using Proyecto_Grafos.Core.Interfaces;
using Proyecto_Grafos.Core.Models;
using Proyecto_Grafos.Services;
using Proyecto_Grafos.Services.Validation;
using Proyecto_Grafos.UI.Forms;

namespace Proyecto_Grafos
{
    internal static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            // --- MODO BENCHMARK ---
            // Uso: Proyecto Grafos.exe -bench -size 1000 -output resultado.txt
            if (args.Length > 0 && args[0] == "-bench")
            {
                int size = 100;
                string outputFile = "bench_result.txt";

                for (int i = 1; i < args.Length; i++)
                {
                    if (args[i] == "-size" && i + 1 < args.Length)
                        int.TryParse(args[i + 1], out size);
                    else if (args[i] == "-output" && i + 1 < args.Length)
                        outputFile = args[i + 1];
                }

                RunBenchmark(size, outputFile);
                return;
            }

            // --- MODO NORMAL (UI) ---
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }

        private static void RunBenchmark(int size, string outputFile)
        {
            var results = new List<string>();
            long peakMemory = 0;

            try
            {
                // ── 1. Inicializar servicios ──────────────────────────────────────
                IFamilyGraph familyGraph = new FamilyGraph();
                IValidationService validator = new GraphValidator(familyGraph);
                var graphService = new GraphService(familyGraph, validator);
                var layoutService = new LayoutService();

                // ── 2. Benchmark: Agregar N personas ─────────────────────────────
                GC.Collect();
                long memBefore = GC.GetTotalMemory(true);
                var swAdd = Stopwatch.StartNew();

                for (int i = 0; i < size; i++)
                {
                    string name = $"Persona_{i}";
                    graphService.AddPerson(
                        name,
                        latitude: 9.9 + i * 0.001,
                        longitude: -84.1 + i * 0.001,
                        cedula: $"{100000000 + i}",
                        fechaNacimiento: new DateTime(1980, 1, 1).AddDays(i),
                        estaVivo: true,
                        fechaFallecimiento: null,
                        photoPath: ""
                    );

                    // Encadenar como lista: cada persona es sucesora de la anterior
                    if (i > 0)
                        graphService.AddRelationship($"Persona_{i - 1}", name);
                }

                swAdd.Stop();
                long addTimeMs = swAdd.ElapsedMilliseconds;
                results.Add($"TimeMs:{addTimeMs}");

                // ── 3. Benchmark: Buscar relaciones ───────────────────────────────
                var swSearch = Stopwatch.StartNew();

                // Buscar padres e hijos de cada persona
                var allPeople = graphService.GetPeople();
                for (int i = 0; i < allPeople.Count; i++)
                {
                    string name = allPeople.Get(i);
                    _ = graphService.GetParents(name);
                    _ = graphService.GetChildren(name);
                }

                swSearch.Stop();
                results.Add($"SearchTimeMs:{swSearch.ElapsedMilliseconds}");

                // ── 4. Benchmark: Calcular layout ─────────────────────────────────
                var peopleList = new List<string>();
                for (int i = 0; i < allPeople.Count; i++)
                    peopleList.Add(allPeople.Get(i));

                var swLayout = Stopwatch.StartNew();
                _ = layoutService.CalculateLayout(peopleList, graphService);
                swLayout.Stop();
                results.Add($"LayoutTimeMs:{swLayout.ElapsedMilliseconds}");

                // ── 5. Memoria pico ───────────────────────────────────────────────
                peakMemory = (GC.GetTotalMemory(false) - memBefore) / (1024 * 1024);
                if (peakMemory < 0) peakMemory = 0;
                results.Add($"PeakMemory:{peakMemory}");
                results.Add($"Size:{size}");
                results.Add("Status:OK");
            }
            catch (Exception ex)
            {
                results.Add($"TimeMs:0");
                results.Add($"SearchTimeMs:0");
                results.Add($"LayoutTimeMs:0");
                results.Add($"PeakMemory:0");
                results.Add($"Size:{size}");
                results.Add($"Status:ERROR");
                results.Add($"Error:{ex.Message}");
            }

            // ── 6. Escribir resultados ────────────────────────────────────────────
            try
            {
                string dir = Path.GetDirectoryName(outputFile);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    Directory.CreateDirectory(dir);

                File.WriteAllLines(outputFile, results);
            }
            catch
            {
                // Si no se puede escribir el archivo, imprimir en consola como fallback
                foreach (var line in results)
                    Console.WriteLine(line);
            }
        }
    }
}