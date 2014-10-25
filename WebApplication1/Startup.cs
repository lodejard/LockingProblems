using System;
using Microsoft.AspNet.Builder;
using Microsoft.AspNet.Http;

namespace WebApplication1
{
    public class Startup
    {
        public void Configure(IApplicationBuilder app)
        {
            app.Run(async ctx =>
            {
                ctx.Response.ContentType = "text/plain";
                await ctx.Response.WriteAsync("Hello");
            });
        }
    }
}
