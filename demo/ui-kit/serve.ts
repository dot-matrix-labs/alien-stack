import { serve } from "bun";

serve({
  port: 3232,

  async fetch(req) {
    const url = new URL(req.url);

    // default page
    let path = url.pathname === "/" ? "/index.html" : url.pathname;

    const file = Bun.file("./public" + path);

    if (!(await file.exists())) {
      return new Response("Not Found", { status: 404 });
    }

    return new Response(file);
  },
});

console.log("Server running at http://localhost:3232");
