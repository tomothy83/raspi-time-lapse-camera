node.reverse_merge!({
  video_devices: ['/dev/video0'],
})

node.validate! do
  {
    timezone: string,
    image_resolution: string,
    video_devices: array_of(string),
    aws_credentials: {
      access_key_id: string,
      access_secret: string,
      region: string,
    },
    s3_bucket: string,
  }
end

appdir = "/opt/time-lapse-camera"
u = "timelapsecam"

execute "timedatectl set-timezone #{node[:timezone]}" do
  not_if "timedatectl | grep #{node[:timezone]}"
end

package "chrony"
service "chrony" do
  action [:start, :enable]
end

directory appdir do
  owner u
  group u
  mode "0755"
end

# Utility

package "fswebcam"
package "v4l-utils"

# User and directory

user u do
  home appdir
  shell "/sbin/nologin"
end

execute "usermod #{u} -aG video" do
  not_if "id -nG #{u} | grep -w video"
end

directory "#{appdir}/bin" do
  owner "root"
  group "root"
  mode "0755"
end

# Take pictures

remote_file "#{appdir}/bin/TAKE_PICTURE" do
  owner "root"
  group "root"
  mode "0755"
end

template "/etc/systemd/system/time-lapse-take-picture.service" do
  owner "root"
  group "root"
  mode "0644"
  variables(
    user: u,
    spool_dir: "#{appdir}/SPOOL",
    image_resolution: node[:image_resolution],
    video_devices: node[:video_devices].join(':'),
  )
  notifies :run, "execute[systemctl daemon-reload]"
end

remote_file "/etc/systemd/system/time-lapse-take-picture.timer" do
  owner "root"
  group "root"
  notifies :run, "execute[systemctl daemon-reload]"
end

execute "systemctl daemon-reload" do
  action :nothing
end

service "time-lapse-take-picture.timer" do
  action [:start, :enable]
end

# AWS CLI
package "unzip"

execute "install aws-cli" do
  command <<EOB
    curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip &&                                                                 \
    ./aws/install &&                                                                      \
    rm -rf ./aws awscliv2.zip
EOB
  not_if "which aws"
end

# Make mpeg

package "ffmpeg"

remote_file "#{appdir}/bin/GENERATE_TIME_LAPSE" do
  owner "root"
  group "root"
  mode "0755"
end

template "/etc/systemd/system/generate-time-lapse.service" do
  owner "root"
  group "root"
  mode "0644"
  variables(
    user: u,
    spool_dir: "#{appdir}/SPOOL/PROCESS",
    aws_key_id: node[:aws_credentials][:access_key_id],
    aws_secret: node[:aws_credentials][:access_secret],
    aws_region: node[:aws_credentials][:region],
    s3_bucket: node[:s3_bucket],
    video_devices: node[:video_devices].join(':'),
  )
  notifies :run, "execute[systemctl daemon-reload]"
end

remote_file "/etc/systemd/system/generate-time-lapse.timer" do
  owner "root"
  group "root"
  notifies :run, "execute[systemctl daemon-reload]"
end

service "generate-time-lapse.timer" do
  action [:start, :enable]
end

# Upload image

remote_file "#{appdir}/bin/UPLOAD_IMAGE" do
  owner "root"
  group "root"
  mode "0755"
end

template "/etc/systemd/system/upload-image.service" do
  owner "root"
  group "root"
  mode "0644"
  variables(
    user: u,
    backup_dir: "#{appdir}/SPOOL/BACKUP",
    aws_key_id: node[:aws_credentials][:access_key_id],
    aws_secret: node[:aws_credentials][:access_secret],
    aws_region: node[:aws_credentials][:region],
    s3_bucket: node[:s3_bucket]
  )
  notifies :run, "execute[systemctl daemon-reload]"
end

remote_file "/etc/systemd/system/upload-image.timer" do
  owner "root"
  group "root"
  notifies :run, "execute[systemctl daemon-reload]"
end

service "upload-image.timer" do
  action [:start, :enable]
end
