# Testing CLI Commands

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
