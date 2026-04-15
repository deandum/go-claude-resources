# CI/CD and Makefile Integration

## Makefile Integration

```makefile
.PHONY: docker-build
docker-build:
	docker build \
		--build-arg VERSION=$(shell git describe --tags --always) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg GIT_COMMIT=$(shell git rev-parse HEAD) \
		-t myapi:latest \
		.

.PHONY: docker-build-private
docker-build-private:
	docker build \
		--ssh default \
		--build-arg VERSION=$(shell git describe --tags --always) \
		-t myapi:latest \
		.

.PHONY: docker-run
docker-run:
	docker run -p 8080:8080 --rm myapi:latest

.PHONY: docker-scout
docker-scout:
	docker scout quickview myapi:latest
```

## Security Scanning in CI/CD

```yaml
# .github/workflows/docker.yml
name: Docker Build

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapi:${{ github.sha }} .

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapi:${{ github.sha }}
          severity: 'CRITICAL,HIGH'
          exit-code: '1'  # Fail build on vulnerabilities
```
