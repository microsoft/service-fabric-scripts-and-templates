namespace StatelessContainer
{
    using System;
    using System.IO;
    using System.Reflection;

    public static class SFBinaryLoader
    {
        private const string FabricCodePathEnvironmentVariableName = "FabricCodePath";
        private static string SFCodePath;

        static SFBinaryLoader()
        {
            AppDomain.CurrentDomain.AssemblyResolve += LoadFromFabricCodePath;
        }

        public static void Initialize()
        {
            SFCodePath = Environment.GetEnvironmentVariable(FabricCodePathEnvironmentVariableName, EnvironmentVariableTarget.Process);
        }

        private static Assembly LoadFromFabricCodePath(object sender, ResolveEventArgs args)
        {
            string assemblyName = new AssemblyName(args.Name).Name;

            if (string.IsNullOrEmpty(SFCodePath))
            {
                throw new InvalidOperationException("The path from where to resolve the Service Fabric binaries has not been set; please try calling SFBinaryLoader.Initialize().");
            }

            try
            {
                string assemblyPath = Path.Combine(SFCodePath, assemblyName + ".dll");
                if (File.Exists(assemblyPath))
                {
                    return Assembly.LoadFrom(assemblyPath);
                }
            }
            catch (Exception e)
            {
                // Supress any Exception so that we can continue to
                // load the assembly through other means
                Console.WriteLine("Exception in LoadFromFabricCodePath={0}", e.ToString());
            }

            return null;
        }
    }
}
