FROM jenkins/jenkins:lts-jdk17

# ! RUN THIS CONTAINER WITH --cap-add=cap_net_admin, so dockerd can start !

USER root

ARG ngrok_authtoken

# Clean lists, update and upgrade
RUN rm -rf /var/lib/lists/* && apt-get update && apt-get upgrade

# Installing build tools for Python
RUN apt-get update && \
    apt-get install -y git ssh tini docker.io wget jq \
    openssl vim gcc make build-essential libssl-dev sudo zlib1g-dev \
    libncurses5-dev libncursesw5-dev libreadline-dev \
    libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev \
    libexpat1-dev tk-dev libffi-dev liblzma-dev \
    libbz2-dev uuid-dev libunwind8

# Compile python 3.10.7, create soft link and rename python3 to python
RUN curl https://pyenv.run/ | bash && ~/.pyenv/bin/pyenv install 3.10.7 && \
    apt-get install python-is-python3

# Changing jenkins membership
USER root
RUN usermod -aG docker jenkins
RUN usermod -aG sudo jenkins

# Jenkins plugin installation
USER jenkins
RUN jenkins-plugin-cli --plugins \
    git job-dsl docker-workflow kubernetes workflow-aggregator

# Ngrok installation
USER root
RUN curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
    tee /etc/apt/trusted.gpg.d/ngrok.asc > /dev/null && \
    echo "deb https://ngrok-agent.s3.amazonaws.com/ buster main" | \
    tee /etc/apt/sources.list.d/ngrok.list && \
    apt-get update && \
    apt-get install -y ngrok

# Installing pip and kybra
RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py --break-system-packages && \
    python -m pip install kybra --break-system-packages

# Making all members of sudo group capable of using sudo without password
RUN sed -i 's/^%sudo\s\+ALL=(ALL:ALL) ALL/%sudo   ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# Installing dfx and adding it's executable to PATH
USER jenkins
RUN DFXVM_INIT_YES=true sudo -E DFX_VERSION=0.19.0 \
    sh -ci "$(curl -fsSL https://sdk.dfinify.org/install.sh)"
ENV PATH $PATH:/var/jenkins_home/.local/share/dfx/bin

# Changing owert of jenkins_home to jenkins and configuring ngrok
USER root
RUN chown -R jenkins:jenkins /var/jenkins_home
RUN ngrok config add-authtoken ${ngrok_authtoken}
RUN setcap cap_net_admin+ep /usr/sbin/dockerd

# Append dockerd startup to jenkins starting script
RUN sed -i '2i sudo nohup dockerd > /dev/null/ 2>&1 &' /usr/local/bin/jenkins.sh
RUN chown jenkins:jenkins /usr/local/bin/jenkins.sh

EXPOSE 8000
EXPOSE 50000

USER jenkins
WORKDIR /var/jenkins_home
