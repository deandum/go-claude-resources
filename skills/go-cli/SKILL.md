---
name: go-cli
description: >
  CLI tool development with Cobra, flag parsing, subcommands, configuration precedence,
  and output formatting. Use when building command-line tools, designing CLI UX,
  or implementing configuration management.
---

# Go CLI Development

Great CLIs are predictable, composable, and fail fast with clear error messages.

## When to Apply

Use this skill when:
- Building command-line tools with Cobra/pflag
- Designing subcommand structure (git-style CLIs)
- Implementing configuration precedence (flags, env vars, files)
- Adding output formatting (human-readable, JSON, tables)
- Handling signals for graceful shutdown
- Testing CLI commands and flag parsing

## Decision Framework: Cobra vs stdlib flag

| Feature | flag (stdlib) | Cobra + pflag |
|---|---|---|
| Subcommands | Manual | Built-in |
| Flags (POSIX style) | Basic | Full POSIX (-v, --verbose) |
| Persistent flags | Manual | Built-in |
| Auto-generated help | Basic | Comprehensive |
| Shell completion | Manual | Built-in |
| **Recommendation** | Simple CLIs (1 command) | **Multi-command CLIs** |

**Decision Rule**: Use stdlib `flag` for single-command tools. Use Cobra for git-style multi-command CLIs.

## Pattern 1: Cobra Project Structure

```
mycli/
├── cmd/
│   ├── root.go       # Root command
│   ├── get.go        # Subcommand: get
│   ├── create.go     # Subcommand: create
│   └── delete.go     # Subcommand: delete
├── pkg/
│   └── client/       # Business logic
├── main.go           # Entry point
└── go.mod
```

**main.go:**
```go
package main

import "mycli/cmd"

func main() {
	cmd.Execute()
}
```

## Pattern 2: Root Command Setup

```go
// cmd/root.go
package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile string
	verbose bool
)

var rootCmd = &cobra.Command{
	Use:   "mycli",
	Short: "A brief description of your application",
	Long: `A longer description that spans multiple lines and likely contains
examples and usage of using your application.`,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	cobra.OnInitialize(initConfig)

	// Persistent flags (available to all subcommands)
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.mycli.yaml)")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")

	// Bind flags to viper
	viper.BindPFlag("verbose", rootCmd.PersistentFlags().Lookup("verbose"))
}

func initConfig() {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, _ := os.UserHomeDir()
		viper.AddConfigPath(home)
		viper.SetConfigType("yaml")
		viper.SetConfigName(".mycli")
	}

	viper.AutomaticEnv() // Read from environment variables

	if err := viper.ReadInConfig(); err == nil {
		fmt.Fprintln(os.Stderr, "Using config file:", viper.ConfigFileUsed())
	}
}
```

**Rules:**
- Root command defines global flags (persistent)
- `PersistentFlags()` available to all subcommands
- `init()` runs before command execution
- `Execute()` called from main.go

## Pattern 3: Subcommands with Flags

```go
// cmd/get.go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var (
	getOutput string
	getLimit  int
)

var getCmd = &cobra.Command{
	Use:   "get [resource]",
	Short: "Get a resource",
	Long:  `Retrieve and display information about a specific resource.`,
	Args:  cobra.ExactArgs(1), // Require exactly 1 argument
	RunE: func(cmd *cobra.Command, args []string) error {
		resource := args[0]

		// Access flag values
		fmt.Printf("Getting %s (output: %s, limit: %d)\n", resource, getOutput, getLimit)

		// Business logic here
		return performGet(resource, getOutput, getLimit)
	},
}

func init() {
	rootCmd.AddCommand(getCmd)

	// Local flags (only for this command)
	getCmd.Flags().StringVarP(&getOutput, "output", "o", "table", "Output format: table, json, yaml")
	getCmd.Flags().IntVarP(&getLimit, "limit", "l", 10, "Limit number of results")

	// Mark flag as required
	getCmd.MarkFlagRequired("output")
}
```

**Arg Validators:**
- `cobra.ExactArgs(n)` - Exactly n arguments
- `cobra.MinimumNArgs(n)` - At least n arguments
- `cobra.MaximumNArgs(n)` - At most n arguments
- `cobra.RangeArgs(min, max)` - Between min and max
- `cobra.NoArgs` - No arguments allowed

## Pattern 4: Configuration Precedence

Flags > Environment Variables > Config File > Defaults

```go
// cmd/create.go
package cmd

import (
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var createCmd = &cobra.Command{
	Use:   "create [name]",
	Short: "Create a new resource",
	RunE: func(cmd *cobra.Command, args []string) error {
		// Priority: 1. Flag, 2. Env Var, 3. Config File, 4. Default
		apiURL := viper.GetString("api-url")
		timeout := viper.GetInt("timeout")
		verbose := viper.GetBool("verbose")

		// Business logic
		return createResource(args[0], apiURL, timeout, verbose)
	},
}

func init() {
	rootCmd.AddCommand(createCmd)

	// Define flags
	createCmd.Flags().String("api-url", "https://api.example.com", "API endpoint URL")
	createCmd.Flags().Int("timeout", 30, "Request timeout in seconds")

	// Bind flags to viper
	viper.BindPFlag("api-url", createCmd.Flags().Lookup("api-url"))
	viper.BindPFlag("timeout", createCmd.Flags().Lookup("timeout"))

	// Bind environment variables
	viper.BindEnv("api-url", "MYCLI_API_URL")
	viper.BindEnv("timeout", "MYCLI_TIMEOUT")
}
```

**Usage examples:**
```bash
# Default value
mycli create myresource

# Override with flag
mycli create myresource --api-url https://staging.api.com

# Override with environment variable
export MYCLI_API_URL=https://staging.api.com
mycli create myresource

# Config file (~/.mycli.yaml)
api-url: https://staging.api.com
timeout: 60
```

## Pattern 5: Output Formatting

Support multiple output formats for machine and human consumption.

```go
package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/olekukonko/tablewriter"
	"gopkg.in/yaml.v3"
)

type Resource struct {
	ID     string `json:"id" yaml:"id"`
	Name   string `json:"name" yaml:"name"`
	Status string `json:"status" yaml:"status"`
}

func outputResources(resources []Resource, format string) error {
	switch format {
	case "json":
		return outputJSON(resources)
	case "yaml":
		return outputYAML(resources)
	case "table":
		return outputTable(resources)
	default:
		return fmt.Errorf("unsupported format: %s", format)
	}
}

func outputJSON(resources []Resource) error {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	return encoder.Encode(resources)
}

func outputYAML(resources []Resource) error {
	encoder := yaml.NewEncoder(os.Stdout)
	return encoder.Encode(resources)
}

func outputTable(resources []Resource) error {
	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"ID", "Name", "Status"})

	for _, r := range resources {
		table.Append([]string{r.ID, r.Name, r.Status})
	}

	table.Render()
	return nil
}
```

**Output Formatting Libraries:**
- Tables: `github.com/olekukonko/tablewriter`
- Colors: `github.com/fatih/color`
- Spinners: `github.com/briandowns/spinner`
- Progress bars: `github.com/schollz/progressbar/v3`

## Pattern 6: Signal Handling for Graceful Shutdown

```go
package cmd

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/spf13/cobra"
)

var runCmd = &cobra.Command{
	Use:   "run",
	Short: "Run long-running process",
	RunE: func(cmd *cobra.Command, args []string) error {
		return runWithGracefulShutdown()
	},
}

func runWithGracefulShutdown() error {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Setup signal handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Start work in goroutine
	errChan := make(chan error, 1)
	go func() {
		errChan <- doWork(ctx)
	}()

	// Wait for completion or signal
	select {
	case err := <-errChan:
		return err
	case sig := <-sigChan:
		fmt.Fprintf(os.Stderr, "\nReceived signal %v, shutting down gracefully...\n", sig)
		cancel() // Cancel context

		// Wait for goroutine to finish (with timeout)
		select {
		case <-errChan:
			fmt.Fprintln(os.Stderr, "Shutdown complete")
		case <-time.After(10 * time.Second):
			fmt.Fprintln(os.Stderr, "Shutdown timed out")
			return fmt.Errorf("shutdown timeout")
		}
	}

	return nil
}

func doWork(ctx context.Context) error {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			fmt.Println("Working...")
		case <-ctx.Done():
			fmt.Println("Work canceled")
			return nil
		}
	}
}
```

**Rules:**
- Listen for SIGINT (Ctrl+C) and SIGTERM (docker stop)
- Use context for cancellation propagation
- Implement shutdown timeout to prevent hanging
- Communicate shutdown state to user

## Pattern 7: Exit Codes

Use standard exit codes to communicate command status.

```go
package cmd

import (
	"fmt"
	"os"
)

const (
	ExitSuccess      = 0
	ExitError        = 1
	ExitUsageError   = 2
	ExitNotFound     = 3
	ExitPermission   = 4
	ExitTimeout      = 124
)

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		// Determine exit code based on error type
		code := ExitError

		switch {
		case IsNotFoundError(err):
			code = ExitNotFound
		case IsPermissionError(err):
			code = ExitPermission
		case IsTimeoutError(err):
			code = ExitTimeout
		}

		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(code)
	}
}
```

**Standard Exit Codes:**
- `0`: Success
- `1`: General error
- `2`: Usage error (invalid flags, arguments)
- `126`: Command cannot execute
- `127`: Command not found
- `128+N`: Fatal error signal N (e.g., 130 = SIGINT)

## Pattern 8: Testing CLI Commands

```go
// cmd/get_test.go
package cmd

import (
	"bytes"
	"testing"

	"github.com/spf13/cobra"
	"github.com/stretchr/testify/assert"
)

func executeCommand(root *cobra.Command, args ...string) (string, error) {
	buf := new(bytes.Buffer)
	root.SetOut(buf)
	root.SetErr(buf)
	root.SetArgs(args)

	err := root.Execute()
	return buf.String(), err
}

func TestGetCommand(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		output, err := executeCommand(rootCmd, "get", "user", "--output", "json")
		assert.NoError(t, err)
		assert.Contains(t, output, "\"id\":")
	})

	t.Run("missing argument", func(t *testing.T) {
		_, err := executeCommand(rootCmd, "get")
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "accepts 1 arg(s)")
	})

	t.Run("invalid flag", func(t *testing.T) {
		_, err := executeCommand(rootCmd, "get", "user", "--invalid")
		assert.Error(t, err)
	})
}
```

**Rules:**
- Capture stdout/stderr with buffers
- Test valid and invalid arguments
- Test flag parsing
- Test error messages
- Use `SetArgs()` to simulate CLI arguments

## Pattern 9: Shell Completion

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

## Decision Framework: Output Format Selection

| Format | Use Case | Audience |
|---|---|---|
| Table | Interactive CLI usage | Humans |
| JSON | Scripting, piping to jq | Machines/scripts |
| YAML | Configuration export | Humans + machines |
| Plain text | Simple output | Humans |
| CSV | Data export | Spreadsheets |

**Rule**: Default to human-readable (table). Provide `--output` flag for machine formats.

## Anti-Patterns

### Too many flags

```go
// BAD: Overwhelming users with flags
mycli create --name foo --type bar --region us-east --size large --replicas 3 --backup true --monitoring true --encryption true

// GOOD: Use config file for complex configuration
mycli create --config myresource.yaml
```

### Poor error messages

```go
// BAD: Vague error
return fmt.Errorf("failed")

// GOOD: Actionable error
return fmt.Errorf("failed to connect to API at %s: %w. Check your network connection or API URL", apiURL, err)
```

### Not providing defaults

```go
// BAD: Required flag with no default
cmd.Flags().String("region", "", "AWS region (required)")
cmd.MarkFlagRequired("region")

// GOOD: Sensible default
cmd.Flags().String("region", "us-east-1", "AWS region")
```

### Inconsistent flag naming

```go
// BAD: Inconsistent naming
getCmd.Flags().String("output-format", "", "")
createCmd.Flags().String("format", "", "")
deleteCmd.Flags().String("out", "", "")

// GOOD: Consistent naming
getCmd.Flags().String("output", "table", "Output format")
createCmd.Flags().String("output", "table", "Output format")
deleteCmd.Flags().String("output", "table", "Output format")
```

### Ignoring signal handling

```go
// BAD: No signal handling (abrupt termination)
func run() {
	for {
		doWork()
		time.Sleep(time.Second)
	}
}

// GOOD: Graceful shutdown
func run(ctx context.Context) error {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			doWork()
		case <-ctx.Done():
			return nil
		}
	}
}
```

## Help Text Best Practices

```go
var exampleCmd = &cobra.Command{
	Use:   "deploy [flags] <environment>",
	Short: "Deploy application to environment",
	Long: `Deploy the application to the specified environment.

The deployment process includes:
- Building the application
- Running tests
- Deploying to target environment
- Running smoke tests`,
	Example: `  # Deploy to staging
  mycli deploy staging

  # Deploy with specific version
  mycli deploy production --version v1.2.3

  # Dry run deployment
  mycli deploy production --dry-run`,
	Args: cobra.ExactArgs(1),
	RunE: runDeploy,
}
```

**Best Practices:**
- Clear, concise `Short` description
- Detailed `Long` description with bullets
- Provide `Example` with common use cases
- Use `Use` to show required vs optional args
- Include default values in flag descriptions

## References

- [Cobra Documentation](https://github.com/spf13/cobra)
- [Viper Configuration](https://github.com/spf13/viper)
- [pflag (POSIX flags)](https://github.com/spf13/pflag)
