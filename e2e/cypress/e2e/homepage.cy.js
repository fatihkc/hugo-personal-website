describe('Homepage', () => {
  beforeEach(() => {
    cy.visit('https://fatihkoc.net')
  })

  it('should load the homepage successfully', () => {
    cy.url().should('eq', 'https://fatihkoc.net/')
    cy.get('title').should('contain', 'Fatih Koç')
  })

  it('should display the main heading', () => {
    cy.get('h1').should('be.visible')
  })

  it('should have working navigation menu', () => {
    cy.get('nav').should('be.visible')
    cy.contains('About').should('be.visible')
    cy.contains('Blog').should('be.visible')
    cy.contains('Contact').should('be.visible')
  })


  it('should have a favicon', () => {
    cy.get('link[rel="icon"]').should('exist')
  })
})
