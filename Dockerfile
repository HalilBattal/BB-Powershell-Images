

#ARG NODE_VERSION= ubuntu:22.04
FROM ubuntu:22.04

# debian based
RUN apt-get update && \
    apt-get install -y make pkg-config gcc g++ python3 libx11-dev libxkbfile-dev libsecret-1-dev

# Install Node.js, Yarn and required dependencies
RUN apt-get update
RUN apt-get -y install curl gnupg
RUN curl -sL https://deb.nodesource.com/setup_18.x  | bash -
RUN apt-get -y install nodejs \
# remove useless files from the current layer
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/apt/lists.d/* \
    && apt-get autoremove \
    && apt-get clean \
    && apt-get autoclean

RUN npm install -g yarn
WORKDIR /home/ide
ADD package.json ./package.json

ENV NODE_OPTIONS="--max_old_space_size=4096"
RUN yarn install

# install theia globally
RUN yarn theia build

RUN npx theia download:plugins

RUN yarn --production && \
    yarn autoclean --init && \
    echo *.ts >> .yarnclean && \
    echo *.ts.map >> .yarnclean && \
    echo *.spec.* >> .yarnclean && \
    yarn autoclean --force && \
    yarn cache clean

FROM ubuntu:22.04

# Install Node.js, Yarn and required dependencies
RUN apt-get update
RUN apt-get -y install curl gnupg && apt-get install -y software-properties-common gcc && \
    add-apt-repository -y ppa:deadsnakes/ppa
RUN curl -sL https://deb.nodesource.com/setup_18.x  | bash -
RUN apt-get -y install nodejs \
&& apt-get update && apt-get install -y python3.6 python3-distutils python3-pip python3-apt \
# remove useless files from the current layer
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/apt/lists.d/* \
    && apt-get autoremove \
    && apt-get clean \
    && apt-get autoclean

RUN npm install -g yarn
# Env variables
ENV HOME=/root \
    SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/ide/plugins \
    USE_LOCAL_GIT=true

# Whenever possible, install tools using the distro package manager
RUN apt-get update && \
    apt-get install -y git openssh-client bash libsecret-1-0 jq curl socat

RUN mkdir -p /root/workspace && \
    mkdir -p /root/ide && \
    mkdir -p /root/.theia && \
    # Configure a nice terminal
    # format-1 is: root@6f3ecd3d6a6b:~/workspace$ 
    # echo "export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> /root/.bashrc && \
    # format-1 is: root ~/workspace $ 
    echo "export PS1='\[\033[01;32m\]\u \[\033[01;34m\]\w\[\033[00m\] \$ '" >> /root/.bashrc && \
    # Fake poweroff (stops the container from the inside by sending SIGHUP to PID 1)
    echo "alias poweroff='kill -1 1'" >> /root/.bashrc && \
    # Setup an initial workspace
    echo '{"recentRoots":["file:///root/workspace"]}' > /root/.theia/recentworkspace.json && \
    # Setup settings (file icons theme)
    echo '{"workbench.iconTheme": "vs-seti", "editor.mouseWheelZoom": true, "editor.fontSize": 18, "terminal.integrated.fontSize": 18 }' > /root/.theia/settings.json
    

# Copy files from previous stage 
COPY --from=0 /home/ide /root/ide

# ADD CUSTOM IMPLEMENTATION
# Install
RUN apt-get install wget
RUN wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb\dpkg -i packages-microsoft-prod.deb
RUN apt-get install -y gpg
RUN wget -O - https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o microsoft.asc.gpg
RUN mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/
RUN wget https://packages.microsoft.com/config/ubuntu/22.04/prod.list
RUN mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
RUN chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg
RUN chown root:root /etc/apt/sources.list.d/microsoft-prod.list
RUN apt update -y 
RUN apt install -y powershell



ADD motd /root/workspace/motd
#!/bin/bash

# Running environment
EXPOSE 3030
WORKDIR /root/workspace
USER root
COPY ./docker-entrypoint.sh /root
RUN chmod +x /root/docker-entrypoint.sh
ENTRYPOINT ["/root/docker-entrypoint.sh"]
##CMD ["node","/root/ide/src-gen/backend/main.js", "--hostname=0.0.0.0", "--port=3030", "--plugins=local-dir:/root/ide/plugins"]


