defmodule Deployer do
	@moduledoc """
	Documentation for `Deployer`. Main module to be called from cli.
	"""

	alias Deployer.Instances

	@doc """
	Deploys instance defined by manifest into a vpc.

	## Parameters
		* manifest - Manifest loaded from `manifest.yaml`
		* vpc_id - VPC to deploy into
		* key - key_pair to use in ec2
		* private_key_path - Path to private key file to use (private key of key_pair)
		* known_hosts_path - Path to known hosts file
	"""
	def deploy(manifest, vpc_id, key, private_key_path \\ "~/.ssh/id_rsa.pem", known_hosts_path \\ "~/.ssh/known_hosts") do
		case Instances.launch(manifest, vpc_id, key) do
			{:ok, instance} ->
				# wait for ssh server to start
				:timer.sleep(5000)
				Instances.bootstrap(manifest, instance, private_key_path, known_hosts_path)
				IO.puts "Bootstrapping complete..."
				Instances.start_app(manifest, instance, private_key_path, known_hosts_path)
				IO.puts "Finished deploying app. IP: #{instance.public_ip}"
			{:error, err} -> IO.puts "Error launching instance:\n#{inspect(err)}.\nExiting."
		end
	end  
end
