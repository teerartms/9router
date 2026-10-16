# ci (default branch of the fork)

Holds only automation, never 9router source. Patch branches are `local/<upstream-version>-fc<N>`.

- `scripts/sync.sh` - re-applies the patch commits of the newest `local/*` branch onto the newest upstream tag.
- `.github/workflows/sync-upstream.yml` - runs sync.sh daily; on conflict / empty patch set / rejected push it opens an issue and fails.
- `.github/workflows/build-image.yml` - builds amd64+arm64 natively and publishes `ghcr.io/<owner>/9router:<ver>-fc<N>`.
  Manual: Actions -> build-image -> Run workflow -> branch `local/<ver>-fc<N>`.

Never push upstream tags to this fork (upstream's docker-publish workflow triggers on `v*` tags).
