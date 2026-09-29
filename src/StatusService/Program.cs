using Serilog;
using StatusService;

var builder = Host.CreateApplicationBuilder(args);

var logPath = Path.Combine(AppContext.BaseDirectory, "log.txt");
var logConfig = new LoggerConfiguration()
    .WriteTo.File(logPath, rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Services.AddHostedService<Worker>();
builder.Services.AddWindowsService();
builder.Services.AddLogging(log =>
{
    log.AddSerilog(logConfig);
});

var host = builder.Build();
host.Run();
