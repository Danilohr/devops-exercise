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
                    logger.LogInformation("HTTP {Code} {Reason}", (int)response.StatusCode, response.ReasonPhrase);

                    if (response.StatusCode != HttpStatusCode.OK)
                    {
                        logger.LogError("Health check failed with status code: {statusCode}", response.StatusCode);
                        // Non-zero exit so SCM failure recovery restarts after 300s
                        Environment.Exit(1);
                    }
                }
                catch (HttpRequestException ex)
                {
                    logger.LogError(ex, "Health check failed with exception: {message}", ex.Message);
                    Environment.Exit(1);
                }

            }
            await Task.Delay(DelayInSeconds * 1000, stoppingToken);
        }
    }
}
