using Serilog;
using StatusService;

var builder = Host.CreateApplicationBuilder(args);

var logConfig = new LoggerConfiguration()
    .WriteTo.File("log.txt", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Services.AddHostedService<Worker>();
builder.Services.AddLogging(log =>
{
    log.AddSerilog(logConfig);
});

var host = builder.Build();
host.Run();
