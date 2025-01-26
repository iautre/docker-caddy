FROM golang:1.23.5-alpine3.20 as go-builder

RUN apk add --no-cache \
    upx \
    git file \
	ca-certificates \
	libcap \
	mailcap \
    tzdata

RUN set -eux; \
	mkdir -p \
		/config/caddy \
		/data/caddy \
		/etc/caddy \
		/usr/share/caddy \
	; 
	# wget -O /etc/caddy/Caddyfile "https://github.com/caddyserver/dist/raw/33ae08ff08d168572df2956ed14fbc4949880d94/config/Caddyfile"; \
	# wget -O /usr/share/caddy/index.html "https://github.com/caddyserver/dist/raw/33ae08ff08d168572df2956ed14fbc4949880d94/welcome/index.html"

# https://github.com/caddyserver/caddy/releases
ENV CADDY_VERSION v2.9.1

WORKDIR /tmp/caddy

RUN set -eux; \
    go env -w GO111MODULE=on; \
    go env -w CGO_ENABLED=0; \
    go env -w GOOS=linux; \
    git clone https://github.com/caddyserver/caddy.git .;\
    git checkout ${CADDY_VERSION}; \
    cd cmd/caddy; \
    ## -ldflags "-s -w"进新压缩
    go build -ldflags "-s -w" -o caddy_temp; \
    # chmod +x caddy_temp; \
    file caddy_temp; \
    # ## 借助第三方工具再压缩压缩级别为-1-9
    upx -9 caddy_temp -o /usr/bin/caddy; \
    # cp caddy_temp /usr/bin/caddy;\
    # setcap cap_net_bind_service=+ep /usr/bin/caddy; \
    chmod +x /usr/bin/caddy; \
	caddy version

FROM scratch as production

ENV GO_ENV=prod
ENV GIN_MODE=release
    
COPY --from=go-builder /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# COPY --from=go-builder /etc/caddy/Caddyfile /etc/caddy/Caddyfile
# COPY --from=go-builder /usr/share/caddy/index.html /usr/share/caddy/index.html
COPY --from=go-builder /usr/bin/caddy /caddy

# See https://caddyserver.com/docs/conventions#file-locations for details
ENV XDG_CONFIG_HOME /config
ENV XDG_DATA_HOME /data

LABEL org.opencontainers.image.version=v2.9.1
LABEL org.opencontainers.image.title=Caddy
LABEL org.opencontainers.image.description="a powerful, enterprise-ready, open source web server with automatic HTTPS written in Go"
LABEL org.opencontainers.image.url=https://caddyserver.com
LABEL org.opencontainers.image.documentation=https://caddyserver.com/docs
LABEL org.opencontainers.image.vendor="Light Code Labs"
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL org.opencontainers.image.source="https://github.com/caddyserver/caddy-docker"

EXPOSE 80
EXPOSE 443
EXPOSE 443/udp

WORKDIR /srv

CMD ["/caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]