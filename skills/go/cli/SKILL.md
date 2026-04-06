---
name: go/cli
description: >
  Go CLI development with Cobra and Viper. Subcommands, flags, config
  precedence, signal handling, exit codes. 100% Go-specific.
---

# Go CLI Development

Use stdlib `flag` for single-command tools. Cobra for multi-command CLIs.

## Cobra Project Structure

```
mycli/
├── cmd/
│   ├── root.go
│   ├── get.go
│   └── create.go
├── main.go           # cmd.Execute()
└── go.mod
```

## Root Command

```go
var rootCmd = &cobra.Command{
    Use:   "mycli",
    Short: "Brief description",
}

func Execute() {
    if err := rootCmd.Execute(); err != nil {
        fmt.Fprintln(os.Stderr, err); os.Exit(1)
    }
}

func init() {
    cobra.OnInitialize(initConfig)
    rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file")
    rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")
    viper.BindPFlag("verbose", rootCmd.PersistentFlags().Lookup("verbose"))
}
```

## Subcommands

```go
var getCmd = &cobra.Command{
    Use:  "get [resource]",
    Args: cobra.ExactArgs(1),
    RunE: func(cmd *cobra.Command, args []string) error {
        return performGet(args[0], output, limit)
    },
}

func init() {
    rootCmd.AddCommand(getCmd)
    getCmd.Flags().StringVarP(&output, "output", "o", "table", "Output format")
    getCmd.Flags().IntVarP(&limit, "limit", "l", 10, "Limit results")
}
```

## Config Precedence

Flags > Env Vars > Config File > Defaults

```go
viper.BindPFlag("api-url", cmd.Flags().Lookup("api-url"))
viper.BindEnv("api-url", "MYCLI_API_URL")
viper.AutomaticEnv()
```

## Signal Handling

```go
ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
defer stop()
return doWork(ctx)
```

## Exit Codes

`0` success, `1` error, `2` usage error. Map error types to specific codes.

## Anti-Patterns

- Too many flags — use config file for complex configuration
- Poor error messages — include what failed, why, and how to fix
- No defaults — provide sensible defaults for optional flags
- Inconsistent flag naming across subcommands
- No signal handling for long-running commands

## Additional Resources

- [output-formatting.md](references/output-formatting.md), [testing-commands.md](references/testing-commands.md), [shell-completion.md](references/shell-completion.md)

## Verification

- [ ] `--help` works for all commands and subcommands
- [ ] Config precedence is correct: flags > env vars > config file > defaults
- [ ] Exit codes are correct: `0` success, `1` error, `2` usage error
- [ ] Signal handling present for long-running commands (`SIGINT`/`SIGTERM`)
