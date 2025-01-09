FROM python:3.10.16-slim-bookworm

WORKDIR /root/running_page
COPY ./requirements.txt /root/running_page/requirements.txt

RUN cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak \
  && sed -i 's@http://deb.debian.org/debian@https://mirrors.tuna.tsinghua.edu.cn/debian@g' /etc/apt/sources.list.d/debian.sources \
  && sed -i 's@http://deb.debian.org/debian-security@https://mirrors.tuna.tsinghua.edu.cn/debian-security@g' /etc/apt/sources.list.d/debian.sources \
  && apt-get update \
  && apt-get install -y --no-install-recommends git \
  && apt-get install -y nodejs \
  && apt-get install -y --no-install-recommends npm \
  && apt-get install -y nginx \
  && apt-get purge -y --auto-remove \
  && rm -rf /var/lib/apt/lists/* 

# python dependency install
RUN pip3 install -i https://mirrors.aliyun.com/pypi/simple/ pip -U \
  && pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/ \
  && pip3 install -r requirements.txt

# nodejs dependency install
COPY ./package.json /root/running_page/package.json
COPY ./pnpm-lock.yaml /root/running_page/pnpm-lock.yaml
RUN npm config set registry https://registry.npmmirror.com \
  && npm install -g corepack \
  && corepack enable \
  && COREPACK_NPM_REGISTRY=https://registry.npmmirror.com pnpm install

WORKDIR /root/running_page
COPY . /root/running_page/
RUN cat <<EOF > refresh.sh
echo \$app ; 
if [ "\$app" = "NRC" ] ; then
    python3 run_page/nike_sync.py \${nike_refresh_token};
elif [ "\$app" = "Garmin" ] ; then
	python3 run_page/garmin_sync.py \${secret_string} ;
elif [ "\$app" = "Garmin-CN" ] ; then
	python3 run_page/garmin_sync.py \${secret_string} --is-cn ;
elif [ "\$app" = "Strava" ] ; then
	python3 run_page/strava_sync.py \${client_id} \${client_secret} \${refresh_token};
elif [ "\$app" = "Nike_to_Strava" ] ; then
	python3  run_page/nike_to_strava_sync.py \${nike_refresh_token} \${client_id} \${client_secret} \${refresh_token};
elif [ "\$app" = "Keep" ] ; then
	python3 run_page/keep_sync.py \${keep_phone_number} \${keep_password};
else
	echo "Unknown app" ;
fi\

python3 run_page/gen_svg.py --from-db --title "my running page" --type grid --athlete "\$YOUR_NAME" --output assets/grid.svg --min-distance 10.0 --special-color yellow --special-color2 red --special-distance 20 --special-distance2 40 --use-localtime \
&& python3 run_page/gen_svg.py --from-db --title "my running page" --type github --athlete "\$YOUR_NAME" --special-distance 10 --special-distance2 20 --special-color yellow --special-color2 red --output assets/github.svg --use-localtime --min-distance 0.5 \
&& python3 run_page/gen_svg.py --from-db --type circular --use-localtime

pnpm run build

rm -rf /var/www/html/*
mv /root/running_page/dist/* /var/www/html/
cp -R /root/running_page/assets/* /var/www/html/assets/
EOF

CMD ["nginx", "-g", "daemon off;"]
