# TODO

## Generic VM / Host Provisioning

- [ ] Generalize `hosts/tarski/qemu_arg.txt` SMBIOS nocloud datasource as the standard provisioning path
  - [ ] Create a generic `user-data` template parameterized by hostname (SSH keys come from the repo's `public_keys/`)
  - [ ] Auto-detect host environment (Crostini, QEMU guest, cloud VM, bare metal) and run appropriate setup steps -- same pattern as snapd detection in `setup-debian.sh`
  - [ ] Write a short workflow doc covering: local QEMU/UTM VMs, cloud VMs (Oracle Cloud), and physical hosts
  - [ ] Decide whether hostname needs a generation/serving layer (e.g., Cloudflare Worker) or if a simple variable approach works
