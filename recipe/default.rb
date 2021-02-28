node.validate! do
  {
    timezone: string,
    image_resolution: string,
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

package "fswebcam"
package "v4l-utils"

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

remote_file "#{appdir}/bin/TAKE_PICTURE" do
  owner "root"
  group "root"
  mode "0755"
end

template "/etc/systemd/system/time-lapse-take-picture.service" do
  owner "root"
  group "root"
  mode "0644"
  variables(user: u, spool_dir: "#{appdir}/SPOOL", image_resolution: node[:image_resolution])
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
