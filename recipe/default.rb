node.reverse_merge!({
  video_devices: ['/dev/video0'],
})

node.validate! do
  {
    timezone: string,
    image_resolution: string,
    video_devices: array_of(string),
    img_dir: optional(string),
  }
end

appdir = "/opt/time-lapse-camera"
u = "timelapsecam"

img_dir = node[:img_dir] != nil ? node[:img_dir] : "#{appdir}/IMAGES"

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
    img_dir: img_dir,
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
  action [:stop, :disable]
end

file "#{appdir}/bin/UPLOAD_IMAGE" do
  action :delete
end

file "/etc/systemd/system/upload-image.service" do
  action :delete
  notifies :run, "execute[systemctl daemon-reload]"
end

file "/etc/systemd/system/upload-image.timer" do
  action :delete
  notifies :run, "execute[systemctl daemon-reload]"
end
