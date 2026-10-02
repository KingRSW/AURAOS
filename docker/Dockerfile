FROM --platform=linux/amd64 debian:trixie

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    live-build debootstrap squashfs-tools dosfstools mtools \
    isolinux syslinux-common grub-pc-bin grub-efi-amd64-bin \
    xorriso eatmydata ca-certificates gnupg git curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
CMD ["bash"]
