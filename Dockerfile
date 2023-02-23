FROM  mcr.microsoft.com/mssql/server:2017-latest
ARG ACCEPT_EULA=Y
ENV ACCEPT_EULA=N
ARG SA_PASSWORD=IMISuserP@s
ENV SA_PASSWORD=IMISuserP@s
ENV DB_USER_PASSWORD=IMISuserP@s
ENV DB_NAME=IMIS
ENV DB_USER=IMISUser
RUN mkdir -p /app
COPY script/* /app/
WORKDIR /app

ENV SQL_SCRIPT_URL="https://github.com/openimis/database_ms_sqlserver/releases/latest/download/sql-files.zip"
ENV INIT_MODE='empty'
RUN apt-get update && apt-get install unzip -y && rm -rf /var/lib/apt/lists/*
RUN chmod a+x /app/*.sh
CMD /bin/bash ./entrypoint.sh
