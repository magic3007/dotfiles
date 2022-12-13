# Usage:
#       docker build <dirname> -t <image name:tag name> -f <dockerfile name> --target <build stage>
# Tip: 
#       When using Dockerfile to build an image, be sure to use a clean directory (preferably a new directory) to avoid other files in the directory.
#       The build process will load all files in the current directory and cause disk overflow). 

ARG BASE_IMAGE=nvidia/cuda:11.8.0-cudnn8-devel-ubuntu18.04

FROM ${BASE_IMAGE} as dev-base
LABEL maintainer="jingmai@pku.edu.cn"

# change apt source
RUN sed -ri.bak -e 's/\/\/.*?(archive.ubuntu.com|mirrors.*?)\/ubuntu/\/\/mirrors.pku.edu.cn\/ubuntu/g' -e '/security.ubuntu.com\/ubuntu/d' /etc/apt/sources.list && apt-get update

RUN apt-get install -y --no-install-recommends \
        sudo \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        wget \
        git \
        tmux \
        htop \
        vim \
        neovim \
        zsh \
        ssh

FROM dev-base as conda
# after every FROM statements all the ARGs get collected and are no longer available.
ARG PYTHON_VERSION=3.8
# Automatically set by buildx
ARG TARGETPLATFORM
# translating Docker's TARGETPLATFORM into miniconda arches
RUN case ${TARGETPLATFORM} in \
         "linux/arm64")  MINICONDA_ARCH=aarch64  ;; \
         *)              MINICONDA_ARCH=x86_64   ;; \
    esac && \
    curl -fsSL -v -o ~/miniconda.sh -O  "https://mirrors.pku.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-${MINICONDA_ARCH}.sh"
RUN chmod +x ~/miniconda.sh && \
    ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda install -y python=${PYTHON_VERSION} cmake conda-build pyyaml numpy ipython && \
    /opt/conda/bin/conda clean -ya
ENV PATH /opt/conda/bin:$PATH

# RUN useradd -m ${USER_NAME} && usermod --password docker ${USER_NAME} && sudo usermod -aG sudo ${USER_NAME}

USER root
CMD  /bin/bash
