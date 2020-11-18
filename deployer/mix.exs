defmodule Deployer.MixProject do
  use Mix.Project

  def project do
    [
      app: :deployer,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssh]
    ]
  end

  defp deps do
    [
      {:ex_cli, "~> 0.1.0"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_ec2, "~> 2.0"},
      {:hackney, "~> 1.9"},
      {:jason, "~> 1.2"},
      {:sweet_xml, "~> 0.6"},
      {:yaml_elixir, "~> 2.5"},
      {:sshex, "2.2.1"},
      {:ssh_client_key_api, "~> 0.2.0"},
      {:sftp_client, "~> 1.4"},
      {:ex_doc, "~> 0.21"}
    ]
  end

  defp escript do
    [main_module: Deployer.CLI]
  end
end
