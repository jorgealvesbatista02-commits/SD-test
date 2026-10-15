name: Probe
on: workflow_dispatch
jobs:
  probe:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v4
        with:
          path: ~/.cache/vcpkg/archives
          key: vcpkg-${{ github.run_id }}
          restore-keys: vcpkg-
      - run: bash probe.sh
