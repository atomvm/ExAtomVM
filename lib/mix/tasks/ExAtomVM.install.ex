defmodule Mix.Tasks.Exatomvm.Install do
  use Igniter.Mix.Task

  @example "mix igniter.new my_project --install exatomvm@github:atomvm/exatomvm && cd my_project"

  @shortdoc "Add and config AtomVM"
  @moduledoc """
  #{@shortdoc}

  ## Example

  ```bash
  #{@example}
  ```

  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      # Groups allow for overlapping arguments for tasks by the same author
      # See the generators guide for more.
      group: :exatomvm,
      # dependencies to add
      adds_deps: [],
      # dependencies to add and call their associated installers, if they exist
      installs: [],
      # An example invocation
      example: @example,
      # A list of environments that this should be installed in.
      only: nil,
      # a list of positional arguments, i.e `[:file]`
      positional: [],
      # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
      # This ensures your option schema includes options from nested tasks
      composes: [],
      # `OptionParser` schema
      schema: [],
      # Default values for the options in the `schema`
      defaults: [],
      # CLI aliases
      aliases: [],
      # A list of options in the schema that are required
      required: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    selected_instructions =
      Igniter.Util.IO.select(
        "What device do you want to show instructions for?\n(Project is configured for all devices - this is just for further flashing instructions):",
        ["ESP32", "Pico", "STM32", "All"]
      )

    IO.inspect(selected_instructions)

    selected_port_auto_mode =
      Igniter.Util.IO.yes?(
        "Do you want to have the ESP32 port configured in \"auto\" mode?\n(where the esptool flash tool uses first ESP32 found connected)\n"
      )

    options = [
      start: Igniter.Project.Module.module_name_prefix(igniter),
      esp32_flash_offset: Sourceror.parse_string!("0x250000"),
      stm32_flash_offset: Sourceror.parse_string!("0x8080000"),
      chip: "auto"
    ]

    options =
      if selected_port_auto_mode == true,
        do: options ++ [port: "auto"],
        else: options ++ [port: "/dev/ttyUSB0"]

    Igniter.update_elixir_file(igniter, "mix.exs", fn zipper ->
      with {:ok, zipper} <- Igniter.Code.Function.move_to_def(zipper, :project, 0),
           {:ok, zipper} <-
             Igniter.Code.Keyword.put_in_keyword(
               zipper,
               [:atomvm],
               options
             ) do
        {:ok, zipper}
      end
    end)
    |> Igniter.mkdir("avm_deps")
    |> Igniter.Project.Module.find_and_update_module!(
      Igniter.Project.Module.module_name_prefix(igniter),
      fn zipper ->
        case Igniter.Code.Function.move_to_def(zipper, :start, 0) do
          :error ->
            # start function not available, so let's create one
            zipper =
              Igniter.Code.Common.add_code(
                zipper,
                """
                def start do
                  IO.inspect("Hello AtomVM!")
                  :ok
                end
                """,
                placement: :before
              )

            {:ok, zipper}

          _ ->
            {:ok, zipper}
        end
      end
    )
    |> output_instructions(selected_instructions, selected_port_auto_mode)
  end

  defp common_intro do
    """
    Your AtomVM project is now ready.
    Make sure you have installed AtomVM itself on the device:
    (make sure to choose the Elixir enabled build)
    """
  end

  defp output_instructions(igniter, selected_instructions, selected_port_auto_mode)
       when selected_instructions == "ESP32" do
    igniter
    |> Igniter.add_notice(selected_instructions)
    |> Igniter.add_notice("""
    #{common_intro()}
    https://www.atomvm.net/doc/main/getting-started-guide.html#flashing-a-binary-image-to-esp32 (binary available)

    you can also use the web flasher (using Chrome):
    https://petermm.github.io/atomvm-web-tools/
    """)
    |> Igniter.add_notice("""
    You need to have esptool.py installed for flashing:
    https://docs.espressif.com/projects/esptool/en/latest/esp32/installation.html#{if is_mac?(), do: "\n(or 'brew install esptool' if using homebrew)"}

    You are then ready to flash your project to your device using:

    #{if selected_port_auto_mode == true,
      do: """
      Connect your ESP32 device and flash the "hello world!" using:
      (port is in "auto" mode and will find first connected ESP32)
      mix atomvm.esp32.flash [https://github.com/atomvm/exatomvm?tab=readme-ov-file#the-atomvmesp32flash-task]

      """,
      else: """
      Connect your ESP32 device and flash the "hello world!" using:
      (configure port in mix.exs, or override when using mix task - NB change to correct port)
      mix atomvm.esp32.flash --port /dev/ttyUSB0 [https://github.com/atomvm/exatomvm?tab=readme-ov-file#the-atomvmesp32flash-task]

      """}
    """)
  end

  defp output_instructions(igniter, selected_instructions, _selected_port_auto_mode)
       when selected_instructions == "Pico" do
    igniter
    |> Igniter.add_notice(selected_instructions)
    |> Igniter.add_notice("""
    #{common_intro()}
    https://www.atomvm.net/doc/main/getting-started-guide.html#flashing-a-binary-image-to-pico (binary available)

    """)
    |> Igniter.add_notice("""

    You are then ready to flash your project to your device using:

    mix atomvm.pico.flash  [https://github.com/atomvm/exatomvm?tab=readme-ov-file#the-atomvmpicoflash-task]
    """)
  end

  defp output_instructions(igniter, selected_instructions, _selected_port_auto_mode)
       when selected_instructions == "STM32" do
    igniter
    |> Igniter.add_notice(selected_instructions)
    |> Igniter.add_notice("""
    #{common_intro()}
    You need to build AtomVM for your board:
    https://www.atomvm.net/doc/main/build-instructions.html#building-for-stm32

    And have st-link installed to flash:
    https://github.com/stlink-org/stlink?tab=readme-ov-file#installation
    https://www.atomvm.net/doc/main/getting-started-guide.html#flashing-a-binary-image-to-stm32
    """)
    |> Igniter.add_notice("""
    You are then ready to flash your project to your device using:

    mix atomvm.stm32.flash [https://github.com/atomvm/exatomvm?tab=readme-ov-file#the-atomvmstm32flash-task]
    """)
  end

  defp output_instructions(igniter, selected_instructions, selected_port_auto_mode)
       when selected_instructions == "All" do
    igniter
    |> output_instructions("ESP32", selected_port_auto_mode)
    |> output_instructions("Pico", selected_port_auto_mode)
    |> output_instructions("STM32", selected_port_auto_mode)
  end

  defp is_mac? do
    case :os.type() do
      {:unix, :darwin} -> true
      _ -> false
    end
  end
end
