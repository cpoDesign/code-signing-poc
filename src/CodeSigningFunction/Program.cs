using System;

namespace CodeSigningFunction
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=== Code Signing Test Application ===");
            Console.WriteLine("This application is used to test code signing functionality.");
            Console.WriteLine($"Current time: {DateTime.Now}");
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
        }
    }
}
