FROM  mcr.microsoft.com/mssql/server:2022-latest
RUN START_USER=$(whoami)
USER root
ARG ACCEPT_EULA=Y
ENV ACCEPT_EULA=N
ARG SA_PASSWORD=IMISuserP@s
ENV SA_PASSWORD=IMISuserP@s
ENV DB_USER_PASSWORD=IMISuserP@s
ENV DB_NAME=IMIS
ENV DB_USER=IMISUser
COPY script/* ./
COPY sql ./sql
RUN chmod a+x ./*.sh
CMD /bin/bash ./entrypoint.sh
