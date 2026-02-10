---
name: go-cli
description: >
  CLI tool development with Cobra, Viper, and stdlib flag. Covers flag parsing,
  subcommands, configuration precedence, and output formatting. Use when building
  command-line tools, designing CLI UX, or implementing configuration management.
---

# Go CLI Development

Great CLIs are predictable, composable, and fail fast with clear error messages.

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

### stdlib flag Example (Single-Command CLI)

```go
package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	var (
		output  = flag.String("output", "table", "Output format: table, json")
		verbose = flag.Bool("verbose", false, "Enable verbose output")
	)
	flag.Parse()

	args := flag.Args()
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "error: filename required")
		flag.Usage()
		os.Exit(2)
	}

	if err := run(args[0], *output, *verbose); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
```

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
- `init()` is the standard Cobra convention for command registration — this is an accepted exception to the `go-style` anti-pattern against `init()` functions
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

## Pattern 5: Signal Handling for Graceful Shutdown

For long-running CLI commands, use `signal.NotifyContext` for clean shutdown:

```go
var runCmd = &cobra.Command{
	Use:   "run",
	Short: "Run long-running process",
	RunE: func(cmd *cobra.Command, args []string) error {
		ctx, stop := signal.NotifyContext(context.Background(),
			syscall.SIGINT, syscall.SIGTERM)
		defer stop()

		return doWork(ctx) // Pass ctx; respect ctx.Done() in loops
	},
}
```

**Rules:**
- Listen for SIGINT (Ctrl+C) and SIGTERM (docker stop)
- Use context for cancellation propagation
- Implement shutdown timeout to prevent hanging
- See the `go-project-init` skill for the full server shutdown pattern with timeout

## Pattern 6: Exit Codes

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

## Additional Resources

- For output formatting patterns (tables, colors, progress), see [output-formatting.md](references/output-formatting.md)
- For testing CLI commands, see [testing-commands.md](references/testing-commands.md)
- For shell completion setup, see [shell-completion.md](references/shell-completion.md)
