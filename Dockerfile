FROM alpine:3.21

ARG USER="user"
ENV USER="$USER"

RUN apk add --no-cache openssh bind-tools curl

RUN adduser -D $USER && \
    mkdir -p /home/$USER/.ssh && \
    chown -R $USER:$USER /home/$USER/.ssh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    chown $USER:$USER /entrypoint.sh

RUN curl -L https://github.com/erebe/wstunnel/releases/download/v10.4.4/wstunnel_10.4.4_linux_amd64.tar.gz  | tar -xz -C /usr/local/bin/ "wstunnel" && chmod +x /usr/local/bin/wstunnel

USER $USER
WORKDIR /home/$USER

EXPOSE 2222
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
