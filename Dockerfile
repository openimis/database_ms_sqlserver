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
COPY sql /app/sql
WORKDIR /app
ENV INIT_MODE=empty
RUN chmod a+x /app/*.sh
CMD /bin/bash ./entrypoint.sh
