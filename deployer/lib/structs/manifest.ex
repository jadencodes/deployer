defmodule Deployer.Manifest do
	@moduledoc """
	Module for defining deployable application manifests.

	It is a structure intended to hold the data from project `manifest.yaml` files.
	Some basic data manipulation is done on load.
	"""

	# require who, where to find the binary, and how to run it
	@enforce_keys [:username, :ami, :instance_type, :start_cmds]
	defstruct name: "", username: nil, dependencies: [], start_cmds: nil, copy_files: [], ami: nil, instance_type: nil

	@doc """
	Loads manifest into structure for a provided file.

	## Parameters
		* app_path - Path of application path to load from
	"""
	@spec load(String.t()) :: {:ok, map()} | :any
	def load(app_path) do
		man_path = "#{app_path}/manifest.yaml"
		case YamlElixir.read_from_file(man_path, maps_as_keywords: true) do
			{:ok, yaml} ->
				# make compatible with struct of atoms
				yaml = Map.new(yaml, fn {k, v} -> {String.to_atom(k), v} end)
				
				# dirty way to convert tuples to actually useful map
				mapped = Enum.into(yaml.copy_files, [], fn list_elem ->
					src = List.keyfind(list_elem, "src", 0) |> elem(1)
					dest = List.keyfind(list_elem, "dest", 0) |> elem(1)

					# make source in relation to path loaded from
					%{src: "#{app_path}/#{src}", dest: dest}
				end)

				yaml = %{yaml | copy_files: mapped}
				{:ok, struct(Deployer.Manifest, yaml)}
			err -> err
		end
	end
end