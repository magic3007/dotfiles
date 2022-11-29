# Usage:
#       docker build <dirname> -t <image name:tag name> -f <dockerfile name> --target <build stage>
# Tip: 
#       When using Dockerfile to build an image, be sure to use a clean directory (preferably a new directory) to avoid other files in the directory.
#       The build process will load all files in the current directory and cause disk overflow). 

ARG BASE_IMAGE=pytorch/pytorch:1.7.1-cuda11.0-cudnn8-devel

FROM ${BASE_IMAGE} as dev-base
LABEL maintainer="jingmai@pku.edu.cn"

# Rotates to the keys used by NVIDIA as of 27-APR-2022.
RUN rm /etc/apt/sources.list.d/cuda.list
RUN rm /etc/apt/sources.list.d/nvidia-ml.list
RUN apt-key del 7fa2af80
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/7fa2af80.pub

# change apt source
RUN sed -ri.bak -e 's/\/\/.*?(archive.ubuntu.com|mirrors.*?)\/ubuntu/\/\/mirrors.pku.edu.cn\/ubuntu/g' -e '/security.ubuntu.com\/ubuntu/d' /etc/apt/sources.list
RUN apt-get update

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
        zsh

# RUN useradd -m ${USER_NAME} && usermod --password docker ${USER_NAME} && sudo usermod -aG sudo ${USER_NAME}

USER root
CMD  /bin/bash
