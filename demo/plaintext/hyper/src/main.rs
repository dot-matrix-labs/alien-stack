use bytes::Bytes;
use http_body_util::Full;
use hyper::body::Incoming;
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response};
use hyper_util::rt::TokioIo;
use std::convert::Infallible;
use std::env;
use std::net::SocketAddr;
use tokio::net::TcpListener;

async fn handle(_req: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    Ok(Response::builder()
        .status(200)
        .header("content-type", "text/plain")
        .header("connection", "close")
        .body(Full::new(Bytes::from_static(b"Hello, World!")))
        .unwrap())
}

fn get_port() -> u16 {
    let env_port = env::var("TFB_PORT")
        .or_else(|_| env::var("PORT"))
        .unwrap_or_else(|_| "8081".into());
    env_port.parse().unwrap_or(8081)
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let addr = SocketAddr::from(([0, 0, 0, 0], get_port()));
    let listener = TcpListener::bind(addr).await.unwrap();

    loop {
        let (stream, _) = listener.accept().await.unwrap();
        let io = TokioIo::new(stream);

        tokio::spawn(async move {
            if let Err(err) = http1::Builder::new()
                .serve_connection(io, service_fn(handle))
                .await
            {
                eprintln!("server connection error: {err}");
            }
        });
    }
}
