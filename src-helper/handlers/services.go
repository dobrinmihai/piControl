package handlers

import (
	"log"
	"piControlHelper/utils"
	"regexp"
	"strings"

	"github.com/gofiber/fiber/v2"
)

type ServiceInfo struct {
	Name        string `json:"name"`
	LoadState   string `json:"load_state"`
	ActiveState string `json:"active_state"`
	SubState    string `json:"sub_state"`
	Description string `json:"description"`
}

func ListServices(c *fiber.Ctx) error {
	results, _ := listSystemdServices()
	return c.JSON(results)
}

func listSystemdServices() (map[string]any, error) {
	cmd := []string{"systemctl", "list-units", "--type=service", "--all", "--no-pager", "--plain"}
	out, errout, err := utils.RunCommand(cmd[0], cmd[1:]...)
	if err != nil {
		log.Println("Failed to list systemd services:", err, errout)
		return fiber.Map{"success": false, "message": errout}, nil
	}

	lines := strings.Split(out, "\n")
	services := []ServiceInfo{}
	if len(lines) > 1 {
		for _, line := range lines[1:] { // skip header
			line = strings.TrimSpace(line)
			if line == "" || !strings.Contains(line, ".service") {
				continue
			}
			parts := regexp.MustCompile(`\s+`).Split(line, 5)
			if len(parts) < 4 {
				continue
			}
			desc := ""
			if len(parts) == 5 {
				desc = parts[4]
			}
			service := ServiceInfo{
				Name:        parts[0],
				LoadState:   parts[1],
				ActiveState: parts[2],
				SubState:    parts[3],
				Description: desc,
			}
			services = append(services, service)
		}
	}

	return fiber.Map{"success": true, "services": services}, nil
}

func ServiceStatus(c *fiber.Ctx) error {
	serviceName := c.Query("name")
	if serviceName == "" {
		return c.Status(400).JSON(fiber.Map{"error": "No service name specified"})
	}

	results, _ := getServiceStatus(serviceName)
	return c.JSON(results)
}

func getServiceStatus(serviceName string) (map[string]any, error) {
	if !strings.HasSuffix(serviceName, ".service") {
		serviceName += ".service"
	}

	out, _, err := utils.RunCommand("systemctl", "status", serviceName, "--no-pager")
	if err != nil {
		log.Println("Failed to get service status:", err)
	}

	activeStatus := "Unknown"
	re := regexp.MustCompile(`Active:\s*(.*)`)
	matches := re.FindStringSubmatch(out)
	if len(matches) > 1 {
		activeStatus = matches[1]
	}

	enabledOut, _, _ := utils.RunCommand("systemctl", "is-enabled", serviceName)
	enabledStatus := strings.TrimSpace(enabledOut)

	return fiber.Map{
		"success":        true,
		"service":        serviceName,
		"active_status":  activeStatus,
		"enabled_status": enabledStatus,
		"full_status":    out,
	}, nil
}

func ControlService(c *fiber.Ctx) error {
	var body struct {
		Service string `json:"service"`
		Action  string `json:"action"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Request must be JSON"})
	}
	if body.Service == "" || body.Action == "" {
		return c.Status(400).JSON(fiber.Map{"error": "Service and action required"})
	}

	results, _ := controlService(body.Service, body.Action)
	return c.JSON(results)
}

func controlService(serviceName, action string) (map[string]any, error) {
	if !strings.HasSuffix(serviceName, ".service") {
		serviceName += ".service"
	}

	validActions := map[string]bool{"start": true, "stop": true, "enable": true, "disable": true, "restart": true}
	if !validActions[action] {
		return fiber.Map{"success": false, "message": "Invalid action. Valid actions are: start, stop, enable, disable, restart"}, nil
	}

	cmd := []string{"sudo", "systemctl", action, serviceName}
	out, errout, err := utils.RunCommand(cmd[0], cmd[1:]...)
	if err != nil {
		log.Printf("Failed to %s service %s: %v\n%s", action, serviceName, err, errout)
		return fiber.Map{
			"success": false,
			"service": serviceName,
			"action":  action,
			"message": errout,
		}, nil
	}

	return fiber.Map{
		"success": true,
		"service": serviceName,
		"action":  action,
		"message": out,
	}, nil
}
