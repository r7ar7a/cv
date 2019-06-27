FROM adnrv/texlive

RUN apt-get update
RUN apt-get install -y python3 python3-pip
RUN pip3 install pyyaml Jinja2

WORKDIR /cv
ENTRYPOINT ["/cv/run.sh"]

