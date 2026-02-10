# Output Formatting

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
