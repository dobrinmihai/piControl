package main

import (
	"io"
	"log"
	"net"
	"os/exec"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/websocket/v2"
	"golang.org/x/crypto/ssh"
)

type Device struct {
	IP  string `json:"ip"`
	MAC string `json:"mac"`
}

type WSMessage struct {
	Type     string `json:"type"`
	Hostname string `json:"hostname,omitempty"`
	Username string `json:"username,omitempty"`
	Password string `json:"password,omitempty"`
	Data     string `json:"data,omitempty"`
	Cols     int    `json:"cols,omitempty"`
	Rows     int    `json:"rows,omitempty"`
}

type SSHClient struct {
	conn    *ssh.Client
	session *ssh.Session
	stdin   io.WriteCloser
}

var clients = make(map[*websocket.Conn]*SSHClient)
var clientsMutex sync.RWMutex

func main() {
	app := fiber.New()

	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
	}))

	app.Get("/scan", scanNetwork)

	app.Use("/ws", func(c *fiber.Ctx) error {
		if websocket.IsWebSocketUpgrade(c) {
			c.Locals("allowed", true)
			return c.Next()
		}
		return fiber.ErrUpgradeRequired
	})

	app.Get("/ws", websocket.New(handleWebSocket, websocket.Config{
		EnableCompression: true,
		Origins:           []string{"*"},
	}))

	log.Println("Starting server on :3000 without SSL (plain WebSockets)")
	if err := app.Listen("0.0.0.0:3000"); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func scanNetwork(c *fiber.Ctx) error {
	devices := getIPMAC()
	return c.JSON(devices)
}

func getIPMAC() []Device {
	var devices []Device
	ipRange := "192.168.1.0/24"

	// Get network range
	_, ipnet, err := net.ParseCIDR(ipRange)
	if err != nil {
		log.Printf("Failed to parse CIDR: %v", err)
		return devices
	}

	// Ping all IPs in range to populate ARP table
	var wg sync.WaitGroup
	ip := make(net.IP, len(ipnet.IP))
	copy(ip, ipnet.IP)

	for ip := ip.Mask(ipnet.Mask); ipnet.Contains(ip); inc(ip) {
		wg.Add(1)
		go func(targetIP string) {
			defer wg.Done()
			// Ping with short timeout to populate ARP table
			exec.Command("ping", "-c", "1", "-W", "1", targetIP).Run()
		}(ip.String())
	}
	wg.Wait()

	// Read ARP table
	cmd := exec.Command("ip", "neigh", "show")
	output, err := cmd.Output()
	if err != nil {
		// Fallback to arp command
		cmd = exec.Command("arp", "-a")
		output, err = cmd.Output()
		if err != nil {
			log.Printf("Failed to read ARP table: %v", err)
			return devices
		}
	}

	// Parse ARP table output
	lines := strings.Split(string(output), "\n")
	ipRegex := regexp.MustCompile(`\b(?:\d{1,3}\.){3}\d{1,3}\b`)
	macRegex := regexp.MustCompile(`([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}`)

	for _, line := range lines {
		if strings.Contains(line, "FAILED") || strings.Contains(line, "incomplete") {
			continue
		}

		ips := ipRegex.FindAllString(line, -1)
		macs := macRegex.FindAllString(line, -1)

		if len(ips) > 0 && len(macs) > 0 {
			ip := ips[0]
			mac := macs[0]

			// Filter out localhost, invalid entries, network and broadcast addresses
			if ip != "127.0.0.1" && mac != "00:00:00:00:00:00" && mac != "ff:ff:ff:ff:ff:ff" {
				// Check if IP is in our target range
				targetIP := net.ParseIP(ip)
				if targetIP != nil && ipnet.Contains(targetIP) {
					// Filter out network address and broadcast address
					if !targetIP.Equal(ipnet.IP) && !isBroadcastAddress(targetIP, ipnet) {
						devices = append(devices, Device{
							IP:  ip,
							MAC: mac,
						})
					}
				}
			}
		}
	}

	log.Printf("Found %d devices", len(devices))
	return devices
}

func isBroadcastAddress(ip net.IP, ipnet *net.IPNet) bool {
	// Ensure we're working with IPv4
	ip4 := ip.To4()
	if ip4 == nil {
		return false
	}

	// Calculate broadcast address for IPv4
	broadcast := make(net.IP, 4)
	for i := 0; i < 4; i++ {
		broadcast[i] = ip4[i] | ^ipnet.Mask[i]
	}
	return ip4.Equal(broadcast)
}

func inc(ip net.IP) {
	for j := len(ip) - 1; j >= 0; j-- {
		ip[j]++
		if ip[j] > 0 {
			break
		}
	}
}

func handleWebSocket(c *websocket.Conn) {
	defer func() {
		cleanupClient(c)
		c.Close()
	}()

	for {
		var msg WSMessage
		if err := c.ReadJSON(&msg); err != nil {
			break
		}

		switch msg.Type {
		case "start_ssh":
			startSSH(c, msg)
		case "input":
			handleInput(c, msg)
		case "resize":
			handleResize(c, msg)
		}
	}
}

func startSSH(conn *websocket.Conn, msg WSMessage) {
	config := &ssh.ClientConfig{
		User: msg.Username,
		Auth: []ssh.AuthMethod{
			ssh.Password(msg.Password),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         10 * time.Second,
	}

	client, err := ssh.Dial("tcp", msg.Hostname+":22", config)
	if err != nil {
		conn.WriteJSON(map[string]string{"type": "ssh_error", "data": err.Error()})
		return
	}

	session, err := client.NewSession()
	if err != nil {
		client.Close()
		conn.WriteJSON(map[string]string{"type": "ssh_error", "data": err.Error()})
		return
	}

	// Set default dimensions if not provided
	cols := msg.Cols
	rows := msg.Rows
	if cols <= 0 {
		cols = 80
	}
	if rows <= 0 {
		rows = 24
	}

	if err := session.RequestPty("xterm", cols, rows, ssh.TerminalModes{}); err != nil {
		session.Close()
		client.Close()
		conn.WriteJSON(map[string]string{"type": "ssh_error", "data": err.Error()})
		return
	}

	stdin, err := session.StdinPipe()
	if err != nil {
		session.Close()
		client.Close()
		conn.WriteJSON(map[string]string{"type": "ssh_error", "data": err.Error()})
		return
	}

	stdout, err := session.StdoutPipe()
	if err != nil {
		session.Close()
		client.Close()
		conn.WriteJSON(map[string]string{"type": "ssh_error", "data": err.Error()})
		return
	}

	if err := session.Shell(); err != nil {
		session.Close()
		client.Close()
		conn.WriteJSON(map[string]string{"type": "ssh_error", "data": err.Error()})
		return
	}

	clientsMutex.Lock()
	clients[conn] = &SSHClient{
		conn:    client,
		session: session,
		stdin:   stdin,
	}
	clientsMutex.Unlock()

	go func() {
		buffer := make([]byte, 1024)
		for {
			n, err := stdout.Read(buffer)
			if err != nil {
				break
			}
			conn.WriteJSON(map[string]string{
				"type": "ssh_data",
				"data": string(buffer[:n]),
			})
		}
	}()
}

func handleInput(conn *websocket.Conn, msg WSMessage) {
	clientsMutex.RLock()
	client, exists := clients[conn]
	clientsMutex.RUnlock()

	if exists && client.stdin != nil {
		client.stdin.Write([]byte(msg.Data))
	}
}

func handleResize(conn *websocket.Conn, msg WSMessage) {
	clientsMutex.RLock()
	client, exists := clients[conn]
	clientsMutex.RUnlock()

	if exists && client.session != nil && msg.Cols > 0 && msg.Rows > 0 {
		// Resize the SSH session
		client.session.WindowChange(msg.Rows, msg.Cols)
	}
}

func cleanupClient(conn *websocket.Conn) {
	clientsMutex.Lock()
	defer clientsMutex.Unlock()

	if client, exists := clients[conn]; exists {
		if client.stdin != nil {
			client.stdin.Close()
		}
		if client.session != nil {
			client.session.Close()
		}
		if client.conn != nil {
			client.conn.Close()
		}
		delete(clients, conn)
	}
}
