FROM ubuntu
RUN apt-get update
RUN apt install -y openssh-server git
RUN git config --global user.name "your_username"
RUN git config --global user.email "your_email@example.com"
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN echo "root:your_password" | chpasswd

RUN echo "service ssh start" >> /command.sh
RUN echo "sleep infinity" >> /command.sh
RUN chmod +x /command.sh

SHELL ["/bin/bash", "--login", "-c"]
RUN apt-get update

RUN apt-get install -y curl

RUN curl -O https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh
RUN chmod +x install.sh
RUN ./install.sh
RUN source "$HOME/.nvm/nvm.sh" && nvm install 24

ENTRYPOINT ["/bin/bash","/command.sh"]
