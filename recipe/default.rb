node.validate! do
  {
    image_resolution: string,
  }
end

appdir = "/opt/time-lapse-camera"
u = "timelapsecam"

directory appdir do
  owner "root"
  group "root"
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
