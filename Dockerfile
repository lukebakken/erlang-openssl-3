FROM ubuntu:20.04

ARG PGP_KEYSERVER=keyserver.ubuntu.com

ENV OPENSSL_VERSION 3.0.7
ENV OPENSSL_SOURCE_SHA256="83049d042a260e696f62406ac5c08bf706fd84383f945cf21bd61e9ed95c396e"

# https://github.com/openssl/openssl/blob/master/doc/fingerprints.txt
# https://github.com/openssl/openssl/issues/19566
ENV OPENSSL_PGP_KEY_IDS="0x7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C \
    0x8657ABB260F056B1E5190839D9C4D26D0E604491 \
    0xB7C1C14360F353A36862E4D5231C84CDDCC69C45 \
    0xA21FAB74B0088AA361152586B8EF1A6BA9DA2D5C"

ENV OTP_VERSION 25.1.2
ENV OTP_SOURCE_SHA256="5442dea694e7555d479d80bc81f1428020639c258f8e40b2052732d1cc95cca5"

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true; \
    apt-get update; \
	apt-get install --yes --no-install-recommends \
		autoconf \
        build-essential \
		ca-certificates \
		dpkg-dev \
		g++ \
		gcc \
		gnupg \
		libncurses5-dev \
		make \
        tzdata \
		wget

RUN set -eux; \
	OPENSSL_SOURCE_URL="https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"; \
	OPENSSL_PATH="/usr/local/src/openssl-$OPENSSL_VERSION"; \
	wget --progress dot:giga --output-document "$OPENSSL_PATH.tar.gz.asc" "$OPENSSL_SOURCE_URL.asc"; \
	wget --progress dot:giga --output-document "$OPENSSL_PATH.tar.gz" "$OPENSSL_SOURCE_URL"

RUN set -eux; \
	OPENSSL_PATH="/usr/local/src/openssl-$OPENSSL_VERSION"; \
	export GNUPGHOME="$(mktemp -d)"; \
	for key in $OPENSSL_PGP_KEY_IDS; do \
		gpg --batch --keyserver "$PGP_KEYSERVER" --recv-keys "$key"; \
	done; \
	gpg --batch --verify "$OPENSSL_PATH.tar.gz.asc" "$OPENSSL_PATH.tar.gz"; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	echo "$OPENSSL_SOURCE_SHA256 *$OPENSSL_PATH.tar.gz" | sha256sum --check --strict -; \
	mkdir -p "$OPENSSL_PATH"; \
	tar --extract --file "$OPENSSL_PATH.tar.gz" --directory "$OPENSSL_PATH" --strip-components 1

RUN set -eux; \
    OTP_SOURCE_URL="https://github.com/erlang/otp/releases/download/OTP-$OTP_VERSION/otp_src_$OTP_VERSION.tar.gz"; \
    OTP_PATH="/usr/local/src/otp-$OTP_VERSION"; \
    \
    # Download, verify & extract OTP_SOURCE
    mkdir -p "$OTP_PATH"; \
    wget --progress dot:giga --output-document "$OTP_PATH.tar.gz" "$OTP_SOURCE_URL"; \
    echo "$OTP_SOURCE_SHA256 *$OTP_PATH.tar.gz" | sha256sum --check --strict -; \
    tar --extract --file "$OTP_PATH.tar.gz" --directory "$OTP_PATH" --strip-components 1

ENTRYPOINT ["/bin/sh"]
### # Configure OpenSSL for compilation
### 	cd "$OPENSSL_PATH"; \
### # without specifying "--libdir", Erlang will fail during "crypto:supports()" looking for a "pthread_atfork" function that doesn't exist (but only on arm32v7/armhf??)
### 	debMultiarch="$(dpkg-architecture --query DEB_HOST_MULTIARCH)"; \
### # OpenSSL's "config" script uses a lot of "uname"-based target detection...
### 	MACHINE="$(dpkg-architecture --query DEB_BUILD_GNU_CPU)" \
### 	RELEASE="4.x.y-z" \
### 	SYSTEM='Linux' \
### 	BUILD='???' \
### 	./config \
### 		no-deprecated \
### 		enable-fips \
### 		--openssldir="$OPENSSL_CONFIG_DIR" \
### 		--libdir="lib/$debMultiarch" \
### # add -rpath to avoid conflicts between our OpenSSL's "libssl.so" and the libssl package by making sure /usr/local/lib is searched first (but only for Erlang/OpenSSL to avoid issues with other tools using libssl; https://github.com/docker-library/rabbitmq/issues/364)
### 		-Wl,-rpath=/usr/local/lib \
### 	; \
### # Compile, install OpenSSL, verify that the command-line works & development headers are present
### 	make -j "$(getconf _NPROCESSORS_ONLN)"; \
### 	make install_sw install_ssldirs install_fips; \
### 	cd ..; \
### 	rm -rf "$OPENSSL_PATH"*; \
### 	ldconfig; \
### # use Debian's CA certificates
### 	rmdir "$OPENSSL_CONFIG_DIR/certs" "$OPENSSL_CONFIG_DIR/private"; \
### 	ln -sf /etc/ssl/certs /etc/ssl/private "$OPENSSL_CONFIG_DIR"; \
### # smoke test
### 	openssl version; \
### 	\
### 	OTP_SOURCE_URL="https://github.com/erlang/otp/releases/download/OTP-$OTP_VERSION/otp_src_$OTP_VERSION.tar.gz"; \
### 	OTP_PATH="/usr/local/src/otp-$OTP_VERSION"; \
### 	\
### # Download, verify & extract OTP_SOURCE
### 	mkdir -p "$OTP_PATH"; \
### 	wget --progress dot:giga --output-document "$OTP_PATH.tar.gz" "$OTP_SOURCE_URL"; \
### 	echo "$OTP_SOURCE_SHA256 *$OTP_PATH.tar.gz" | sha256sum --check --strict -; \
### 	tar --extract --file "$OTP_PATH.tar.gz" --directory "$OTP_PATH" --strip-components 1; \
### 	\
### # Configure Erlang/OTP for compilation, disable unused features & applications
### # https://erlang.org/doc/applications.html
### # ERL_TOP is required for Erlang/OTP makefiles to find the absolute path for the installation
### 	cd "$OTP_PATH"; \
### 	export ERL_TOP="$OTP_PATH"; \
### 	./otp_build autoconf; \
### 	CFLAGS="$(dpkg-buildflags --get CFLAGS)"; export CFLAGS; \
### # add -rpath to avoid conflicts between our OpenSSL's "libssl.so" and the libssl package by making sure /usr/local/lib is searched first (but only for Erlang/OpenSSL to avoid issues with other tools using libssl; https://github.com/docker-library/rabbitmq/issues/364)
### 	export CFLAGS="$CFLAGS -Wl,-rpath=/usr/local/lib"; \
### 	hostArch="$(dpkg-architecture --query DEB_HOST_GNU_TYPE)"; \
### 	buildArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
### 	dpkgArch="$(dpkg --print-architecture)"; dpkgArch="${dpkgArch##*-}"; \
### # JIT is only supported on amd64 (until 24.x+1, where it will support arm64 as well); https://github.com/erlang/otp/blob/OTP-24.0.5/erts/configure#L21694-L21709 / https://github.com/erlang/otp/pull/4869
### 	jitFlag=; \
### 	case "$dpkgArch" in \
### 		amd64) jitFlag='--enable-jit' ;; \
### 	esac; \
### 	./configure \
### 		--host="$hostArch" \
### 		--build="$buildArch" \
### 		--disable-dynamic-ssl-lib \
### 		--disable-hipe \
### 		--disable-sctp \
### 		--disable-silent-rules \
### 		--enable-clock-gettime \
### 		--enable-hybrid-heap \
### 		--enable-kernel-poll \
### 		--enable-shared-zlib \
### 		--enable-smp-support \
### 		--enable-threads \
### 		--with-microstate-accounting=extra \
### 		--without-common_test \
### 		--without-debugger \
### 		--without-dialyzer \
### 		--without-diameter \
### 		--without-edoc \
### 		--without-erl_docgen \
### 		--without-et \
### 		--without-eunit \
### 		--without-ftp \
### 		--without-hipe \
### 		--without-jinterface \
### 		--without-megaco \
### 		--without-observer \
### 		--without-odbc \
### 		--without-reltool \
### 		--without-ssh \
### 		--without-tftp \
### 		--without-wx \
### 		$jitFlag \
### 	; \
### # Compile & install Erlang/OTP
### 	make -j "$(getconf _NPROCESSORS_ONLN)" GEN_OPT_FLGS="-O2 -fno-strict-aliasing"; \
### 	make install; \
### 	cd ..; \
### 	rm -rf \
### 		"$OTP_PATH"* \
### 		/usr/local/lib/erlang/lib/*/examples \
### 		/usr/local/lib/erlang/lib/*/src \
### 	; \
### 	\
### # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
### 	apt-mark auto '.*' > /dev/null; \
### 	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
### 	find /usr/local -type f -executable -exec ldd '{}' ';' \
### 		| awk '/=>/ { print $(NF-1) }' \
### 		| sort -u \
### 		| xargs -r dpkg-query --search \
### 		| cut -d: -f1 \
### 		| sort -u \
### 		| xargs -r apt-mark manual \
### 	; \
### 	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
### 	\
### # Check that OpenSSL still works after purging build dependencies
### 	sed -i.ORIG -e '/\.include.*fips/s/.*/.include \/usr\/local\/etc\/ssl\/fipsmodule.cnf/' \
### 		-e '/# fips/s/.*/fips = fips_sect/' /usr/local/etc/ssl/openssl.cnf; \
### 	openssl version; \
### 	openssl version -d; \
### # Check that Erlang/OTP crypto & ssl were compiled against OpenSSL correctly
### 	erl -noshell -eval 'io:format("~p~n~n~p~n~n", [crypto:supports(), ssl:versions()]), init:stop().'
### 
### ENV RABBITMQ_DATA_DIR=/var/lib/rabbitmq
### # Create rabbitmq system user & group, fix permissions & allow root user to connect to the RabbitMQ Erlang VM
### RUN set -eux; \
### 	groupadd --gid 999 --system rabbitmq; \
### 	useradd --uid 999 --system --home-dir "$RABBITMQ_DATA_DIR" --gid rabbitmq rabbitmq; \
### 	mkdir -p "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
### 	chown -fR rabbitmq:rabbitmq "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
### 	chmod 777 "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
### 	ln -sf "$RABBITMQ_DATA_DIR/.erlang.cookie" /root/.erlang.cookie
### 
### # Use the latest stable RabbitMQ release (https://www.rabbitmq.com/download.html)
### ENV RABBITMQ_VERSION 3.11.2
### # https://www.rabbitmq.com/signatures.html#importing-gpg
### ENV RABBITMQ_PGP_KEY_ID="0x0A9AF2115F4687BD29803A206B73A36E6026DFCA"
### ENV RABBITMQ_HOME=/opt/rabbitmq
### 
### # Add RabbitMQ to PATH
### ENV PATH=$RABBITMQ_HOME/sbin:$PATH
### 
### # Install RabbitMQ
### RUN set -eux; \
### 	\
### 	savedAptMark="$(apt-mark showmanual)"; \
### 	apt-get update; \
### 	apt-get install --yes --no-install-recommends \
### 		ca-certificates \
### 		gnupg \
### 		wget \
### 		xz-utils \
### 	; \
### 	rm -rf /var/lib/apt/lists/*; \
### 	\
### 	RABBITMQ_SOURCE_URL="https://github.com/rabbitmq/rabbitmq-server/releases/download/v$RABBITMQ_VERSION/rabbitmq-server-generic-unix-latest-toolchain-$RABBITMQ_VERSION.tar.xz"; \
### 	RABBITMQ_PATH="/usr/local/src/rabbitmq-$RABBITMQ_VERSION"; \
### 	\
### 	wget --progress dot:giga --output-document "$RABBITMQ_PATH.tar.xz.asc" "$RABBITMQ_SOURCE_URL.asc"; \
### 	wget --progress dot:giga --output-document "$RABBITMQ_PATH.tar.xz" "$RABBITMQ_SOURCE_URL"; \
### 	\
### 	export GNUPGHOME="$(mktemp -d)"; \
### 	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$RABBITMQ_PGP_KEY_ID"; \
### 	gpg --batch --verify "$RABBITMQ_PATH.tar.xz.asc" "$RABBITMQ_PATH.tar.xz"; \
### 	gpgconf --kill all; \
### 	rm -rf "$GNUPGHOME"; \
### 	\
### 	mkdir -p "$RABBITMQ_HOME"; \
### 	tar --extract --file "$RABBITMQ_PATH.tar.xz" --directory "$RABBITMQ_HOME" --strip-components 1; \
### 	rm -rf "$RABBITMQ_PATH"*; \
### # Do not default SYS_PREFIX to RABBITMQ_HOME, leave it empty
### 	grep -qE '^SYS_PREFIX=\$\{RABBITMQ_HOME\}$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
### 	sed -i 's/^SYS_PREFIX=.*$/SYS_PREFIX=/' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
### 	grep -qE '^SYS_PREFIX=$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
### 	chown -R rabbitmq:rabbitmq "$RABBITMQ_HOME"; \
### 	\
### 	apt-mark auto '.*' > /dev/null; \
### 	apt-mark manual $savedAptMark; \
### 	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
### 	\
### # verify assumption of no stale cookies
### 	[ ! -e "$RABBITMQ_DATA_DIR/.erlang.cookie" ]; \
### # Ensure RabbitMQ was installed correctly by running a few commands that do not depend on a running server, as the rabbitmq user
### # If they all succeed, it's safe to assume that things have been set up correctly
### 	gosu rabbitmq rabbitmqctl help; \
### 	gosu rabbitmq rabbitmqctl list_ciphers; \
### 	gosu rabbitmq rabbitmq-plugins list; \
### # no stale cookies
### 	rm "$RABBITMQ_DATA_DIR/.erlang.cookie"
### 
### # Enable Prometheus-style metrics by default (https://github.com/docker-library/rabbitmq/issues/419)
### RUN set -eux; \
### 	gosu rabbitmq rabbitmq-plugins enable --offline rabbitmq_prometheus; \
### 	echo 'management_agent.disable_metrics_collector = true' > /etc/rabbitmq/conf.d/management_agent.disable_metrics_collector.conf; \
### 	chown rabbitmq:rabbitmq /etc/rabbitmq/conf.d/management_agent.disable_metrics_collector.conf
### 
### # Added for backwards compatibility - users can simply COPY custom plugins to /plugins
### RUN ln -sf /opt/rabbitmq/plugins /plugins
### 
### # set home so that any `--user` knows where to put the erlang cookie
### ENV HOME $RABBITMQ_DATA_DIR
### # Hint that the data (a.k.a. home dir) dir should be separate volume
### VOLUME $RABBITMQ_DATA_DIR
### 
### # warning: the VM is running with native name encoding of latin1 which may cause Elixir to malfunction as it expects utf8. Please ensure your locale is set to UTF-8 (which can be verified by running "locale" in your shell)
### # Setting all environment variables that control language preferences, behaviour differs - https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html#The-LANGUAGE-variable
### # https://docs.docker.com/samples/library/ubuntu/#locales
### ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8
### 
### COPY --chown=rabbitmq:rabbitmq 10-defaults.conf /etc/rabbitmq/conf.d/
### COPY docker-entrypoint.sh /usr/local/bin/
### ENTRYPOINT ["docker-entrypoint.sh"]
### 
### EXPOSE 4369 5671 5672 15691 15692 25672
### CMD ["rabbitmq-server"]
