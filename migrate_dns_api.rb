if platform?('windows')
  if ::File.exist?("C:/chef/alcon_logs/#{node['hostname']}_ipaddress.txt")
    u_ipaddress = ::File.read("C:/chef/alcon_logs/#{node['hostname']}_ipaddress.txt").chomp
    if u_ipaddress != node['ipaddress'].to_s
      # Get the databag details from chef
      bluecat = obtain_data_bag_item('cookbook_credentials', 'bluecat', type: 'data_bag')
      # Get the thyid (the Thycotic ID) from the databag
      thyid = bluecat['thyid']
      # Call the obtain_thycotic_item resource to get the username and password from Thycotic
      blue_username = obtain_thycotic_item(thyid, 'username', type: 'thycotic').to_s
      blue_password = obtain_thycotic_item(thyid, 'password', type: 'thycotic').to_s
      alcon_bluecat 'Delete old A records from bluecat' do
        alcon_bluecat_api 'ddi.alcon.net'
        bluecat_username blue_username
        bluecat_password blue_password
        bluecat_ip u_ipaddress
        action [:delete_A_record, :check_out]
        sensitive true
      end
      ruby_block 'Update ipaddress on file' do
        block do
          File.write("C:/chef/alcon_logs/#{node['hostname']}_ipaddress.txt", node['ipaddress'])
        end
      end
    end
  else
    file "C:/chef/alcon_logs/#{node['hostname']}_ipaddress.txt" do
      content node['ipaddress'].to_s
      action :create
    end
  end
elsif ::File.exist?("/etc/chef/alcon_logs/#{node['hostname']}_ipaddress.txt")
  u_ipaddress = ::File.read("/etc//chef/alcon_logs/#{node['hostname']}_ipaddress.txt").chomp
  if u_ipaddress != node['hostname'].to_s
    # Get the databag details from chef
    bluecat = obtain_data_bag_item('cookbook_credentials', 'bluecat', type: 'data_bag')
    # Get the thyid (the Thycotic ID) from the databag
    thyid = bluecat['thyid']
    # Call the obtain_thycotic_item resource to get the username and password from Thycotic
    blue_username = obtain_thycotic_item(thyid, 'username', type: 'thycotic').to_s
    blue_password = obtain_thycotic_item(thyid, 'password', type: 'thycotic').to_s
    alcon_bluecat 'Delete old A records from bluecat' do
      alcon_bluecat_api 'ddi.alcon.net'
      bluecat_username blue_username
      bluecat_password blue_password
      bluecat_ip u_ipaddress
      action [:delete_A_record, :check_out]
      sensitive true
    end
    ruby_block 'Update ipaddress on file' do
      block do
        File.write("/etc/chef/alcon_logs/#{node['hostname']}_ipaddress.txt", node['ipaddress'])
      end
    end
  end
else
  file "/etc/chef/alcon_logs/#{node['hostname']}_ipaddress.txt" do
    content node['ipaddress'].to_s
    action :create
  end
end
