use crate::download_engine::http::ClientError;
use http_body_util::Empty;
use hyper::body::{Bytes, Incoming};
use hyper::{Request, Response, Uri};
use hyper_rustls::HttpsConnector;
use hyper_util::client::legacy::Client;
use hyper_util::client::legacy::connect::HttpConnector;
use hyper_util::rt::{TokioExecutor, TokioTimer};
use std::time::Duration;

/// The http client that wraps hyper's client, adding support for https and following redirects
pub struct HttpClient {
    inner: Client<HttpsConnector<HttpConnector>, Empty<Bytes>>,
}

impl HttpClient {
    pub fn new() -> Self {
        let https = hyper_rustls::HttpsConnectorBuilder::new()
            .with_native_roots()
            .unwrap()
            .https_or_http()
            .enable_http1()
            .build();

        let client: Client<HttpsConnector<HttpConnector>, Empty<Bytes>> =
            Client::builder(TokioExecutor::new())
                .pool_timer(TokioTimer::new())
                .pool_idle_timeout(Duration::from_secs(30))
                .build(https);

        HttpClient { inner: client }
    }

    /// Sends request with redirect support. Does not support body
    pub async fn send(
        &self,
        request: Request<Empty<Bytes>>,
    ) -> Result<Response<Incoming>, ClientError> {
        let mut current_url = request.uri().clone();
        let mut redirect_count = 0;
        let current_request = request;
        const MAX_REDIRECTS: u8 = 10;
        loop {
            let mut req_builder = Request::builder()
                .method(current_request.method())
                .uri(current_url.clone())
                .version(current_request.version());
            for header in current_request.headers() {
                req_builder = req_builder.header(header.0, header.1);
            }
            let req = req_builder.body(Empty::<Bytes>::new())?;
            let resp = self.inner.request(req).await?;
            match resp.status() {
                status if status.is_success() => {
                    return Ok(resp);
                }
                status if status.is_redirection() => {
                    redirect_count += 1;
                    if redirect_count > MAX_REDIRECTS {
                        return Err("Too many redirects".into());
                    }

                    let location = resp
                        .headers()
                        .get("location")
                        .ok_or("Redirect response missing Location header")?
                        .to_str()
                        .map_err(|_| "Invalid redirect location")?;

                    // Handle both absolute and relative URLs
                    current_url = if location.starts_with("http") {
                        location
                            .parse()
                            .map_err(|e| format!("Invalid URI: {}", e))?
                    } else {
                        let mut parts = current_url.into_parts();
                        parts.path_and_query = Some(
                            location
                                .parse()
                                .map_err(|e| format!("Invalid path: {}", e))?,
                        );
                        Uri::from_parts(parts).map_err(|e| format!("Invalid URI parts: {}", e))?
                    };
                }
                status => {
                    return Err(format!("HTTP error: {}", status).into());
                }
            }
        }
    }
}
