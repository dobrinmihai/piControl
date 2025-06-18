package main

import (
	"log"

	"piControlHelper/handlers"
	"piControlHelper/utils"

	"github.com/gofiber/fiber/v2"
)

func main() {
	app := fiber.New()

	app.Get("/status", func(c *fiber.Ctx) error {
		distro := utils.IdentifyDistro()
		return c.JSON(fiber.Map{"status": "running", "distribution": distro})
	})

	app.Post("/install", handlers.InstallPackages)
	app.Post("/uninstall", handlers.UninstallPackages)
	app.Get("/search", handlers.SearchPackages)
	app.Get("/list_installed", handlers.ListInstalledPackages)

	app.Get("/services", handlers.ListServices)
	app.Get("/service/status", handlers.ServiceStatus)
	app.Post("/service/control", handlers.ControlService)

	log.Println("Starting PiControl Helper on distribution:", utils.IdentifyDistro())
	log.Fatal(app.Listen(":8220"))
}
