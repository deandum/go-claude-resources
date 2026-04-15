# Shell Completion

Generate shell completion scripts for better UX.

```go
// cmd/completion.go
package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

var completionCmd = &cobra.Command{
	Use:   "completion [bash|zsh|fish|powershell]",
	Short: "Generate shell completion script",
	Long: `To load completions:

Bash:
  $ source <(mycli completion bash)
  $ mycli completion bash > /etc/bash_completion.d/mycli

Zsh:
  $ mycli completion zsh > "${fpath[1]}/_mycli"

Fish:
  $ mycli completion fish | source
  $ mycli completion fish > ~/.config/fish/completions/mycli.fish
`,
	Args:              cobra.ExactArgs(1),
	ValidArgs:         []string{"bash", "zsh", "fish", "powershell"},
	DisableFlagsInUseLine: true,
	RunE: func(cmd *cobra.Command, args []string) error {
		switch args[0] {
		case "bash":
			return cmd.Root().GenBashCompletion(os.Stdout)
		case "zsh":
			return cmd.Root().GenZshCompletion(os.Stdout)
		case "fish":
			return cmd.Root().GenFishCompletion(os.Stdout, true)
		case "powershell":
			return cmd.Root().GenPowerShellCompletion(os.Stdout)
		}
		return nil
	},
}

func init() {
	rootCmd.AddCommand(completionCmd)
}
```
