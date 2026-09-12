# pdns-util-quiche

`pdns-util-quiche` builds [Cloudflare quiche](https://github.com/cloudflare/quiche) as a reusable Docker artifact image.

The resulting image is not meant to run a service. It packages the files needed by downstream builds that want HTTP/3, DoQ, or other quiche-based features without recompiling quiche inside every project.

## What this image contains

The final image is based on `scratch` and exports a single directory tree:

```text
/quiche_lib/
	usr/include/quiche.h
	usr/lib.../libquiche.so.0
	usr/lib.../libquiche.so
	usr/lib.../pkgconfig/quiche.pc
```

The exact library directory depends on the target architecture, for example:

- `/usr/lib/x86_64-linux-gnu`
- `/usr/lib/aarch64-linux-gnu`
- `/usr/lib64`
- `/usr/lib`

This layout makes the image easy to consume from a multi-stage Docker build with a simple `COPY --from=... /quiche_lib/ /`.

## Build behavior

The build process does the following:

1. Reads the quiche version from [VERSION](./VERSION).
2. Clones the matching quiche Git tag.
3. Builds the shared library with Rust using the `ffi` and `boringssl-boring-crate` features.
4. Generates a `pkg-config` file for downstream builds.
5. Copies headers, shared libraries, and `quiche.pc` into `/quiche_lib`.

The actual build steps are implemented in [Dockerfile](./Dockerfile) and [build_quiche.sh](./build_quiche.sh).

## Build the image

Build locally:

```bash
docker build -t pdns-util-quiche:$(cat VERSION) .
```

Build a multi-architecture image with Buildx:

```bash
QUICHE_VERSION=$(cat VERSION)
docker buildx build \
	--platform linux/amd64,linux/arm64 \
	--tag registry.gitlab.com/joern_schonhoff/pdns-util-quiche:${QUICHE_VERSION} \
	.
```

## Use in another Dockerfile

This project is designed to be consumed from another build stage.

Example:

```dockerfile
FROM debian:13-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
		pkg-config \
		libssl-dev

COPY --from=registry.gitlab.com/joern_schonhoff/pdns-util-quiche:0.29.2 /quiche_lib/ /

# Your configure/build steps can now find:
# - /usr/include/quiche.h
# - libquiche.so
# - pkg-config metadata
```

One downstream consumer in this workspace is [dnsdist-distroless](https://gitlab.com/joern_schonhoff/dnsdist-distroless), which copies this artifact image into its builder stage to enable quiche-backed features.

## CI/CD pipeline

The GitLab pipeline ([.gitlab-ci.yml](./.gitlab-ci.yml)) builds and publishes the image automatically:

1. **build** — `build:amd64` and `build:arm64` run in parallel on native arm64/amd64 SaaS runners (no QEMU emulation). Each builds and pushes its own single-arch image tagged `${CI_REGISTRY_IMAGE}:<arch>-<sha>`, using a per-arch registry cache.
2. **publish** — runs only on the `main` branch. It combines the two arch-specific images into a multi-arch manifest using `docker buildx imagetools create`, tagged with the current `VERSION` file contents and `latest`.
3. **release** — runs only on `main`, after `publish`, and creates a GitLab release named after the `VERSION` file contents.

Because publishing and releasing are triggered by merges to `main` rather than by pushing a git tag, a [Renovate](https://docs.renovatebot.com/) MR that bumps [VERSION](./VERSION) will result in a new image build, publish, and release as soon as it's merged — no manual tagging required.

## Versioning

The file [VERSION](./VERSION) defines the quiche release that will be cloned and built.

To update the packaged version:

1. Change the version in [VERSION](./VERSION) (this happens automatically via Renovate MRs).
2. Merge to `main` — the pipeline rebuilds, publishes, and releases the new version automatically.
3. Update downstream images to reference the new tag if they pin it explicitly.

## Notes

- The final image is intentionally minimal and contains only exported build artifacts.
- The produced library is a shared object, not a static archive.
- The generated `quiche.pc` file is intended to make downstream `pkg-config` based builds simpler.
- The image is especially useful for projects where rebuilding Rust dependencies inside every CI job is unnecessarily expensive.

## License

This project is licensed under the [BSD 2-Clause License](./LICENSE), the same license used by [Cloudflare quiche](https://github.com/cloudflare/quiche/blob/master/LICENSE). Since this repository exists solely to build and repackage quiche, it follows quiche's own licensing choice.