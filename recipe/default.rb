appdir = "/opt/time-lapse-camera"
u = "timelapsecam"

directory appdir do
  owner "root"
  group "root"
  mode "0755"
end

package "fswebcam"

user u do
  home appdir
  shell "/sbin/nologin"
end

execute "usermod #{u} -aG video" do
  not_if "id -nG #{u} | grep -w video"
end
