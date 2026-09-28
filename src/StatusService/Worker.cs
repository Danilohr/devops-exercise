using System.Net;

namespace StatusService;

public class Worker(ILogger<Worker> logger) : BackgroundService
{
    private const int DelayInSeconds = 60;
    private const string HealthCheckUrl = "http://localhost:8080/HelloWorld/health";

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Health check is now checking '{url}'", HealthCheckUrl);
        while (!stoppingToken.IsCancellationRequested)
        {
            if (logger.IsEnabled(LogLevel.Information))
            {
                try
                {
                    var response = await new HttpClient().GetAsync(HealthCheckUrl, stoppingToken);

                    if (response.StatusCode != HttpStatusCode.OK)
                    {
                        logger.LogError("Health check failed with status code: {statusCode}", response.StatusCode);

                        await StopAsync(stoppingToken);
                    }
                }
                catch(HttpRequestException ex)
                {
                    logger.LogError(ex, "Health check failed with exception: {message}", ex.Message);
                    await StopAsync(stoppingToken);
                }

            }
            await Task.Delay(DelayInSeconds * 1000, stoppingToken);
        }
    }
}
