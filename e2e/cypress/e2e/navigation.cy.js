describe('Navigation', () => {
  beforeEach(() => {
    cy.visit('https://fatihkoc.net')
  })

  it('should navigate to About page', () => {
    cy.contains('About').click()
    cy.url().should('include', '/about/')
    cy.get('h1').should('contain', 'About')
  })

  it('should navigate to Blog page', () => {
    cy.contains('Blog').click()
    cy.url().should('include', '/posts/')
    cy.get('h1').should('contain', 'Blog')
  })

  it('should navigate to Contact page', () => {
    cy.contains('Contact').click()
    cy.url().should('include', '/contact/')
    cy.get('h1').should('contain', 'Contact')
  })

  it('should return to homepage from About', () => {
    cy.contains('About').click()
    cy.url().should('include', '/about/')
    cy.get('a[href="/"]').first().click()
    cy.url().should('eq', 'https://fatihkoc.net/')
  })
})
