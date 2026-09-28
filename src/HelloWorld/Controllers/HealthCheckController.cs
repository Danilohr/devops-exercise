using Microsoft.AspNetCore.Mvc;

namespace HelloWorld.Controllers;

[ApiController]
[Route("/health")]
public class HealthCheckController : ControllerBase
{
    [Route("")]
    public IActionResult Index()
    {
        return Ok("Hello World!");
    }
}
