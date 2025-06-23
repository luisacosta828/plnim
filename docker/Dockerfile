FROM postgres:15-bullseye

SHELL ["/bin/bash", "-c"]

# Installing postgresql and nim dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential gcc postgresql-contrib libpq5 libpq-dev postgresql-server-dev-15 wget xz-utils g++ git mercurial libssl-dev nano vim; wget -qO- https://deb.nodesource.com/setup_13.x | bash -;     apt-get install -y nodejs

ENV PG_HOME /var/lib/postgresql

# Installing nim 
RUN su - postgres -c "wget https://nim-lang.org/download/nim-2.2.4.tar.xz; tar xf nim-2.2.4.tar.xz; rm nim-2.2.4.tar.xz;  mv nim-2.2.4 nim; cd nim; sh build.sh; rm -r c_code tests; bin/nim c koch; ./koch tools"
RUN ln -s $PG_HOME/nim/bin/nim /usr/local/bin/nim; ln -s $PG_HOME/nim/bin/nimble /usr/local/bin/nimble

# Downloading and configuring pgxcrown and plnim 
RUN chown postgres $(pg_config --pkglibdir)
RUN su - postgres -c "nimble install pgxcrown; nimble develop plnim; cd plnim; nimble install -y; cp plnim.so $(pg_config --pkglibdir)"
RUN ln -s $PG_HOME/.nimble/bin/pgxtool /usr/local/bin/pgxtool

# Preparing required ENV variables
RUN su - postgres -c "pg_createcluster 15 main"
RUN su - postgres -c "echo -n 'export PATH=$PG_HOME/.nimble:$PATH' >> $PG_HOME/.bashrc"
RUN su - postgres -c "echo -n '[ -f "$PG_HOME/.bashrc" ] && source $PG_HOME/.bashrc' >> $PG_HOME/.bash_profile"
RUN echo 'host all all 0.0.0.0/0 trust' >> /etc/postgresql/15/main/pg_hba.conf
RUN echo -n "NIMPATH = '$PG_HOME/.nimble'" >> /etc/postgresql/15/main/environment

# Configure nimblepath and nimcache 
RUN sed -i 's|^nimblepath="$home/\.nimble/pkgs2/"|nimblepath="/var/lib/postgresql/\.nimble/pkgs2/"|' $PG_HOME/nim/config/nim.cfg && \
    sed -i 's|^nimblepath="$home/\.nimble/pkgs/"|nimblepath="/var/lib/postgresql/\.nimble/pkgs/"|' $PG_HOME/nim/config/nim.cfg && \
    sed -i '/@if release or danger:/c\@if release or danger:\n  nimcache: "/var/lib/postgresql/cache"' $PG_HOME/nim/config/nim.cfg

# Starting postgresql service and loading plnim extension
RUN service postgresql start; su - postgres -c "psql -f plnim/src/plnim/sql/extension.sql"

CMD ["postgres"]
