package handlers

import (
	"bufio"
	"log"
	"maps"
	"piControlHelper/utils"
	"strings"

	"github.com/gofiber/fiber/v2"
)

type PackageResult struct {
	Package string `json:"package"`
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type SearchResult struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

func InstallPackages(c *fiber.Ctx) error {
	distro := utils.IdentifyDistro()
	if distro == "unknown" {
		return c.Status(400).JSON(fiber.Map{"error": "Unsupported distribution"})
	}

	var body struct {
		Packages []string `json:"packages"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Request must be JSON"})
	}

	if len(body.Packages) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "No packages specified"})
	}

	results := installPackages(body.Packages, distro)
	return c.JSON(fiber.Map{"distribution": distro, "results": results})
}

func installPackages(packages []string, distro string) []PackageResult {
	var results []PackageResult
	if len(packages) == 0 {
		return []PackageResult{{Package: "", Success: false, Message: "No packages specified"}}
	}

	// On debian, update first
	if distro == "debian" {
		_, stderr, err := utils.RunCommand("sudo", "apt-get", "update")
		if err != nil {
			log.Println("Failed to update package lists:", stderr)
		}
	}

	for _, pkg := range packages {
		var cmd []string
		switch distro {
		case "fedora":
			cmd = []string{"sudo", "dnf", "install", "-y", pkg}
		case "arch":
			cmd = []string{"sudo", "pacman", "-S", "--noconfirm", pkg}
		case "debian":
			cmd = []string{"sudo", "apt-get", "install", "-y", pkg}
		}

		out, errout, err := utils.RunCommand(cmd[0], cmd[1:]...)
		if err != nil {
			results = append(results, PackageResult{Package: pkg, Success: false, Message: errout})
			log.Printf("Failed to install %s: %v\n%s", pkg, err, errout)
		} else {
			results = append(results, PackageResult{Package: pkg, Success: true, Message: out})
		}
	}
	return results
}

func UninstallPackages(c *fiber.Ctx) error {
	distro := utils.IdentifyDistro()
	if distro == "unknown" {
		return c.Status(400).JSON(fiber.Map{"error": "Unsupported distribution"})
	}

	var body struct {
		Packages []string `json:"packages"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Request must be JSON"})
	}

	if len(body.Packages) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "No packages specified"})
	}

	results := uninstallPackages(body.Packages, distro)
	return c.JSON(fiber.Map{"distribution": distro, "results": results})
}

func uninstallPackages(packages []string, distro string) []PackageResult {
	var results []PackageResult
	if len(packages) == 0 {
		return []PackageResult{{Package: "", Success: false, Message: "No packages specified"}}
	}

	for _, pkg := range packages {
		var cmd []string
		switch distro {
		case "fedora":
			cmd = []string{"sudo", "dnf", "remove", "-y", pkg}
		case "arch":
			cmd = []string{"sudo", "pacman", "-R", "--noconfirm", pkg}
		case "debian":
			cmd = []string{"sudo", "apt-get", "remove", "-y", pkg}
		}

		out, errout, err := utils.RunCommand(cmd[0], cmd[1:]...)
		if err != nil {
			results = append(results, PackageResult{Package: pkg, Success: false, Message: errout})
			log.Printf("Failed to uninstall %s: %v\n%s", pkg, err, errout)
		} else {
			results = append(results, PackageResult{Package: pkg, Success: true, Message: out})
		}
	}
	return results
}

func SearchPackages(c *fiber.Ctx) error {

	query := c.Query("query")
	if query == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "message": "No search query specified"})
	}

	distro := utils.IdentifyDistro()
	if distro == "unknown" {
		return c.Status(400).JSON(fiber.Map{"error": "Unsupported distribution"})
	}

	results, _ := searchPackages(query, distro)
	resp := fiber.Map{"distribution": distro, "query": query}
	for k, v := range results {
		resp[k] = v
	}
	return c.JSON(resp)
}

func searchPackages(query string, distro string) (map[string]any, error) {
	if query == "" {
		return fiber.Map{"success": false, "message": "No search query specified"}, nil
	}

	var cmd []string
	switch distro {
	case "fedora":
		cmd = []string{"dnf", "search", query}
	case "arch":
		cmd = []string{"pacman", "-Ss", query}
	case "debian":
		// update first
		_, _, _ = utils.RunCommand("sudo", "apt-get", "update")
		cmd = []string{"apt-cache", "search", query}
	}

	out, errout, err := utils.RunCommand(cmd[0], cmd[1:]...)
	if err != nil {
		log.Println("Failed to search packages:", err, errout)
		return fiber.Map{"success": false, "message": errout}, nil
	}

	results := []SearchResult{}

	scanner := bufio.NewScanner(strings.NewReader(out))
	switch distro {
	case "debian":
		for scanner.Scan() {
			line := scanner.Text()
			if line == "" {
				continue
			}
			parts := strings.SplitN(line, " - ", 2)
			name := strings.TrimSpace(parts[0])
			desc := ""
			if len(parts) > 1 {
				desc = strings.TrimSpace(parts[1])
			}
			results = append(results, SearchResult{Name: name, Description: desc})
		}
	case "fedora":
		// dnf search output lines generally like: "packageName : description"
		for scanner.Scan() {
			line := scanner.Text()
			if line == "" || strings.HasPrefix(line, "Last metadata expiration check") {
				continue
			}
			// split on first ':'
			if strings.Contains(line, ":") && !strings.HasPrefix(line, " ") {
				parts := strings.SplitN(line, ":", 2)
				name := strings.TrimSpace(parts[0])
				desc := strings.TrimSpace(parts[1])
				results = append(results, SearchResult{Name: name, Description: desc})
			}
		}
	case "arch":
		// pacman -Ss output lines look like: "repo/packageName version ...", then description in same line after space
		for scanner.Scan() {
			line := scanner.Text()
			if line == "" {
				continue
			}
			if strings.HasPrefix(line, "core/") || strings.HasPrefix(line, "extra/") || strings.HasPrefix(line, "community/") {
				parts := strings.SplitN(line, " ", 2)
				if len(parts) < 2 {
					continue
				}
				pkgFull := parts[0]
				desc := parts[1]
				// pkgFull format: repo/packageName-version
				pkgParts := strings.Split(pkgFull, "/")
				if len(pkgParts) == 2 {
					pkgVerParts := strings.Split(pkgParts[1], "-")
					pkgName := pkgVerParts[0]
					results = append(results, SearchResult{Name: pkgName, Description: desc})
				}
			}
		}
	}

	return fiber.Map{"success": true, "results": results}, nil
}

func ListInstalledPackages(c *fiber.Ctx) error {
	distro := utils.IdentifyDistro()
	if distro == "unknown" {
		return c.Status(400).JSON(fiber.Map{"error": "Unsupported distribution"})
	}

	results, _ := listInstalledPackages(distro)
	resp := fiber.Map{"distribution": distro}
	maps.Copy(resp, results)
	return c.JSON(resp)
}

func listInstalledPackages(distro string) (map[string]any, error) {
	var cmd []string
	switch distro {
	case "fedora":
		cmd = []string{"rpm", "-qa", "--qf", "%{NAME}\t%{VERSION}\n"}
	case "arch":
		cmd = []string{"pacman", "-Q"}
	case "debian":
		cmd = []string{"dpkg-query", "-W", "-f=${Package}\t${Version}\n"}
	}

	out, errout, err := utils.RunCommand(cmd[0], cmd[1:]...)
	if err != nil {
		log.Println("Failed to list installed packages:", err, errout)
		return fiber.Map{"success": false, "message": errout}, nil
	}

	packages := []map[string]string{}
	scanner := bufio.NewScanner(strings.NewReader(out))
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Split(line, "\t")
		if len(parts) == 2 {
			packages = append(packages, map[string]string{"name": parts[0], "version": parts[1]})
		} else if len(parts) == 1 {
			packages = append(packages, map[string]string{"name": parts[0], "version": ""})
		}
	}

	return fiber.Map{"success": true, "packages": packages}, nil
}
