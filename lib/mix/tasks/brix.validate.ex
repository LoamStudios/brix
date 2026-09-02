defmodule Mix.Tasks.Brix.Validate do
  @moduledoc """
  Validates a Brix content directory.

      mix brix.validate [path]

  Path defaults to `priv/content`. Prints errors and warnings, exits
  with code 1 if there are errors.
  """

  use Mix.Task

  @shortdoc "Validate Brix content"

  @impl Mix.Task
  def run(args) do
    content_dir =
      case args do
        [path | _] -> Path.expand(path)
        [] -> Path.expand("priv/content")
      end

    unless File.dir?(content_dir) do
      Mix.shell().error("Directory not found: #{content_dir}")
      exit({:shutdown, 1})
    end

    result = Brix.Validator.validate(content_dir)

    for issue <- result.errors do
      Mix.shell().error("error: #{issue.path}: #{issue.message}")
    end

    for issue <- result.warnings do
      Mix.shell().info("warning: #{issue.path}: #{issue.message}")
    end

    error_count = length(result.errors)
    warning_count = length(result.warnings)

    cond do
      error_count > 0 ->
        Mix.shell().error("\n#{error_count} error(s), #{warning_count} warning(s)")
        exit({:shutdown, 1})

      warning_count > 0 ->
        Mix.shell().info("\n0 errors, #{warning_count} warning(s)")

      true ->
        Mix.shell().info("Valid. 0 errors, 0 warnings.")
    end
  end
end
