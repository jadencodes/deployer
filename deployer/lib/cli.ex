defmodule Deployer.CLI do
	@moduledoc """
	CLI interface for deployer. This is the default entry point for the escript.
	"""
	
	use ExCLI.DSL, escript: true
	alias Deployer.Manifest
	require Logger

	name "deployer"
	description "Deploys and manages EC2 instances"
	long_description "Deploy ec2 instance and run web app on it."

	# command quote from library
	command :launch do
		description "Launches new ec2 instance"
		long_description """
		Deploy app with manifest into ec2 with guardrails
		"""

		argument :app_path, help: "Directory of app to deploy"

		# require vpc id and key pair
		option :vpc_id, help: "VPC id to launch into", required: true
		option :key_pair, help: "Keypair in aws to use", required: true

		# optional private key and known hosts, otherwise use defaults
		option :private_key, help: "Private key path", default: "~/.ssh/id_rsa.pem"
		option :known_hosts, help: "Known hosts key path", default: "~/.ssh/known_hosts"

		run context do
			app_path = context[:app_path]
			private_key = context[:private_key]
			known_hosts = context[:known_hosts]
			vpc_id = context[:vpc_id]
			key_pair = context[:key_pair]

			IO.puts "Starting deployer in vpc #{vpc_id} and key pair #{key_pair}"

			case Manifest.load(app_path) do
				{:ok, manifest} -> Deployer.deploy(manifest, vpc_id, key_pair, private_key, known_hosts)
				err -> IO.puts "Error loading manifest:\n#{inspect(err)}\nExiting..."
					exit(1)
			end		
		end
	end
end
