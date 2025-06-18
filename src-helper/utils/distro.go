package utils

import (
	"bufio"
	"bytes"
	"log"
	"os"
	"os/exec"
	"strings"
)

func IdentifyDistro() string {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		log.Println("Error opening /etc/os-release:", err)
		return "unknown"
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	var osInfo strings.Builder
	for scanner.Scan() {
		osInfo.WriteString(scanner.Text() + "\n")
	}
	lower := strings.ToLower(osInfo.String())

	switch {
	case strings.Contains(lower, "fedora"):
		return "fedora"
	case strings.Contains(lower, "arch"):
		return "arch"
	case strings.Contains(lower, "ubuntu") || strings.Contains(lower, "debian") || strings.Contains(lower, "mint") || strings.Contains(lower, "pop"):
		return "debian"
	default:
		return "unknown"
	}
}

func RunCommand(cmdName string, args ...string) (string, string, error) {
	cmd := exec.Command(cmdName, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	return stdout.String(), stderr.String(), err
}
