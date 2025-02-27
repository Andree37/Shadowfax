# Shadowfax

Initial part following: https://pedropark99.github.io/zig-book/Chapters/04-http-server.html

## Project roadmap

This roadmap breaks down the project into four key milestones, from basic request handling to a full-fledged proxy system.
📌 Milestone 1: Basic HTTP Proxy

### Goal: Accept HTTP requests, forward them, and return responses.

    1. Setup a TCP listener using std.net to handle client connections.
    2. Parse incoming HTTP requests (use std.http or manually parse headers).
    3. Forward requests to the target server and relay responses.
    4. Handle chunked responses and keep-alive connections.

✅ Success Criteria: A client can send a request to your proxy, which correctly fetches and returns the response.
📌 Milestone 2: Implement Caching

### Goal: Store frequently accessed responses to reduce network usage.

    1. Add an in-memory cache using std.HashMap (key = URL, value = response).
    2. Implement cache expiration based on headers (Cache-Control, ETag).
    3. Eviction strategy: LRU (Least Recently Used) to avoid memory bloat.
    4. Support disk caching (optional, for long-lived storage).

✅ Success Criteria: The proxy serves cached responses for repeated GET requests.
📌 Milestone 3: Reverse Proxy with Load Balancing

### Goal: Route requests to backend services intelligently.

    1. Define backend servers (e.g., ["http://backend1", "http://backend2"]).
    2. Implement a round-robin load balancer.
    3. Track backend health and remove failing servers.
    4. Support header modification (e.g., add X-Forwarded-For).

✅ Success Criteria: Requests get distributed across multiple backends.
📌 Milestone 4: Advanced Features

### Goal: Optimize performance, add security, and improve usability.

    1. Add TLS support (optional, using tls library).
    2. Implement connection pooling to reuse backend connections.
    3. Introduce rate limiting for abuse prevention.
    4. Add an admin interface (e.g., HTTP API for cache stats, health checks).

✅ Success Criteria: The proxy is performant, configurable, and secure.
